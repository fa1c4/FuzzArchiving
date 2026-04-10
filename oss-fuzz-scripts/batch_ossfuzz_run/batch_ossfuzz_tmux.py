#!/usr/bin/env python3
import argparse
import json
import os
import re
import shlex
import signal
import subprocess
import sys
import time
from collections import deque
from dataclasses import dataclass, asdict, field
from datetime import datetime
from pathlib import Path
from typing import Deque, Dict, List, Optional, Sequence, Set


DEFAULT_CRASH_PREFIXES = (
    "crash-",
    "leak-",
    "timeout-",
    "oom-",
    "slow-unit-",
)

SKIP_OUT_NAMES = (
    "centipede",
    "llvm-symbolizer",
)

SKIP_OUT_PREFIXES = (
    "afl-",
    "jazzer_",
)


def now_str() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def log(msg: str) -> None:
    print(f"[{now_str()}] {msg}", flush=True)


@dataclass
class ProjectInfo:
    index: int
    name: str
    path: str
    files: List[str]


@dataclass
class BuildResult:
    project: str
    index: int
    success: bool
    rc: int
    duration_sec: float
    out_dir: str
    fuzzers: List[str] = field(default_factory=list)
    error: Optional[str] = None


@dataclass
class FuzzerJob:
    project: str
    project_index: int
    fuzzer: str
    out_dir: str
    log_path: str
    session_name: str = ""


@dataclass
class FuzzerResult:
    project: str
    project_index: int
    fuzzer: str
    session_name: str
    log_path: str
    status: str
    started_at: str
    ended_at: str
    duration_sec: float
    crash_count: int = 0
    new_crash_files: List[str] = field(default_factory=list)
    note: Optional[str] = None


class ManagedProcessError(RuntimeError):
    pass


def safe_name(text: str, max_len: int = 80) -> str:
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", text).strip("_")
    if not safe:
        safe = "item"
    return safe[:max_len]


def unique_session_name(project: str, fuzzer: str) -> str:
    base = f"fuzz_{safe_name(project, 24)}_{safe_name(fuzzer, 24)}"
    suffix = str(int(time.time() * 1000))[-8:]
    return f"{base}_{suffix}"[:120]


def shutil_which(name: str) -> Optional[str]:
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(directory) / name
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def tmux_session_exists(session_name: str) -> bool:
    result = subprocess.run(
        ["tmux", "has-session", "-t", session_name],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def snapshot_crash_files(out_dir: Path, crash_prefixes: Sequence[str]) -> Set[str]:
    if not out_dir.exists():
        return set()

    found: Set[str] = set()
    for path in out_dir.rglob("*"):
        if not path.is_file():
            continue
        if any(path.name.startswith(prefix) for prefix in crash_prefixes):
            try:
                found.add(str(path.relative_to(out_dir)))
            except ValueError:
                found.add(str(path))
    return found


def tail_text(path: Path, max_lines: int = 80) -> str:
    if not path.exists():
        return ""
    try:
        content = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    return "\n".join(content[-max_lines:])


def infer_status_from_log(text: str) -> str:
    lowered = text.lower()
    if not text.strip():
        return "failed"

    crash_markers = [
        "addresssanitizer",
        "undefinedbehaviorsanitizer",
        "memorysanitizer",
        "test unit written to",
        "artifact_prefix",
        "crash",
        "leak",
        "timeout",
        "oom",
        "slow-unit",
    ]
    if any(marker in lowered for marker in crash_markers):
        return "crash"
    return "finished"


def build_tmux_command(
    repo_root: Path,
    project: str,
    fuzzer: str,
    engine: str,
    sanitizer: str,
    timeout_sec: int,
    log_path: Path,
) -> str:
    helper_cmd = " ".join(
        shlex.quote(part)
        for part in [
            "python",
            "infra/helper.py",
            "run_fuzzer",
            "--engine",
            engine,
            "--sanitizer",
            sanitizer,
            project,
            fuzzer,
        ]
    )

    shell_script = (
        f"cd {shlex.quote(str(repo_root))} && "
        f"export PYTHONUNBUFFERED=1; "
        f"set -o pipefail; "
        f"timeout --preserve-status --signal=TERM {timeout_sec}s {helper_cmd} "
        f"2>&1 | tee -a {shlex.quote(str(log_path))}"
    )
    return f"bash -lc {shlex.quote(shell_script)}"


class Runner:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.repo_root = Path(args.repo_root).resolve()
        self.projects_dir = self.repo_root / args.projects_dir
        self.build_out_root = self.repo_root / "build" / "out"
        self.state_dir = (self.repo_root / args.state_dir).resolve()
        self.logs_dir = self.state_dir / "logs"

        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.logs_dir.mkdir(parents=True, exist_ok=True)

        self.scan_json = (self.state_dir / args.scan_json).resolve()
        self.result_json = (self.state_dir / args.result_json).resolve()

        self.projects: List[ProjectInfo] = []
        self.build_results: List[BuildResult] = []
        self.fuzzer_results: List[FuzzerResult] = []
        self._stop_requested = False

    def register_signal_handlers(self) -> None:
        def _handler(signum, _frame) -> None:
            self._stop_requested = True
            log(f"Received signal {signum}. Stopping new jobs and attempting to clean up tmux sessions.")

        signal.signal(signal.SIGINT, _handler)
        signal.signal(signal.SIGTERM, _handler)

    def ensure_prerequisites(self) -> None:
        if not self.repo_root.exists():
            raise ManagedProcessError(f"repo_root does not exist: {self.repo_root}")
        if not (self.repo_root / "infra" / "helper.py").exists():
            raise ManagedProcessError(f"infra/helper.py was not found under {self.repo_root}")
        if not self.projects_dir.exists():
            raise ManagedProcessError(f"projects directory does not exist: {self.projects_dir}")

        for tool in ("python", "tmux"):
            if shutil_which(tool) is None:
                raise ManagedProcessError(f"Missing required command: {tool}")

    def scan_projects(self) -> List[ProjectInfo]:
        project_paths = sorted(
            [p for p in self.projects_dir.iterdir() if p.is_dir()],
            key=lambda p: p.name,
        )

        projects: List[ProjectInfo] = []
        for index, path in enumerate(project_paths):
            files = sorted([x.name for x in path.iterdir()])
            projects.append(
                ProjectInfo(
                    index=index,
                    name=path.name,
                    path=str(path.resolve()),
                    files=files,
                )
            )

        payload = {
            "generated_at": now_str(),
            "repo_root": str(self.repo_root),
            "projects_dir": str(self.projects_dir),
            "count": len(projects),
            "index_base": 0,
            "projects": [asdict(p) for p in projects],
        }
        self.scan_json.write_text(
            json.dumps(payload, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
        log(f"Wrote project scan results to {self.scan_json}")
        return projects

    def select_projects(self, projects: List[ProjectInfo]) -> List[ProjectInfo]:
        if self.args.start_index > self.args.end_index:
            raise ManagedProcessError("--start-index cannot be greater than --end-index")
        return [
            p
            for p in projects
            if self.args.start_index <= p.index <= self.args.end_index
        ]

    def discover_fuzzers(self, out_dir: Path) -> List[str]:
        if not out_dir.exists():
            return []

        fuzzers: List[str] = []
        for path in sorted(out_dir.iterdir(), key=lambda p: p.name):
            name = path.name
            if name in SKIP_OUT_NAMES:
                continue
            if any(name.startswith(prefix) for prefix in SKIP_OUT_PREFIXES):
                continue
            if not path.is_file():
                continue
            if path.stat().st_mode & 0o111:
                fuzzers.append(name)
        return fuzzers

    def build_project(self, project: ProjectInfo) -> BuildResult:
        started = time.time()
        out_dir = self.build_out_root / project.name
        out_dir.mkdir(parents=True, exist_ok=True)

        command = [
            "python",
            "infra/helper.py",
            "build_fuzzers",
            "--sanitizer",
            self.args.sanitizer,
            "--engine",
            self.args.engine,
            project.name,
        ]
        log(f"Starting build for project[{project.index}] {project.name}: {' '.join(map(shlex.quote, command))}")

        proc = subprocess.run(
            command,
            cwd=self.repo_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        duration = time.time() - started
        build_log_path = self.logs_dir / f"build__{safe_name(project.name)}.log"
        build_log_path.write_text(proc.stdout or "", encoding="utf-8", errors="replace")

        if proc.returncode != 0:
            log(f"Build failed: {project.name} (rc={proc.returncode}), log: {build_log_path}")
            return BuildResult(
                project=project.name,
                index=project.index,
                success=False,
                rc=proc.returncode,
                duration_sec=duration,
                out_dir=str(out_dir),
                error=f"build failed, see {build_log_path}",
            )

        fuzzers = self.discover_fuzzers(out_dir)
        log(f"Build succeeded: {project.name}, discovered {len(fuzzers)} fuzzers.")
        return BuildResult(
            project=project.name,
            index=project.index,
            success=True,
            rc=0,
            duration_sec=duration,
            out_dir=str(out_dir),
            fuzzers=fuzzers,
        )

    def start_tmux_job(self, job: FuzzerJob) -> str:
        session = unique_session_name(job.project, job.fuzzer)
        job.session_name = session

        log_path = Path(job.log_path)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text("", encoding="utf-8")

        command = build_tmux_command(
            repo_root=self.repo_root,
            project=job.project,
            fuzzer=job.fuzzer,
            engine=self.args.engine,
            sanitizer=self.args.sanitizer,
            timeout_sec=self.args.fuzz_time_sec,
            log_path=log_path,
        )

        subprocess.run(
            ["tmux", "new-session", "-d", "-s", session, command],
            check=True,
            cwd=self.repo_root,
        )
        log(f"Started tmux session={session} project={job.project} fuzzer={job.fuzzer}")
        return session

    def kill_tmux_session(self, session_name: str) -> None:
        subprocess.run(
            ["tmux", "kill-session", "-t", session_name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )

    def flush_results_json(self) -> None:
        payload = {
            "generated_at": now_str(),
            "repo_root": str(self.repo_root),
            "engine": self.args.engine,
            "sanitizer": self.args.sanitizer,
            "start_index": self.args.start_index,
            "end_index": self.args.end_index,
            "max_tmuxs": self.args.max_tmuxs,
            "fuzz_time_hours": self.args.fuzz_time_hours,
            "scan_json": str(self.scan_json),
            "build_results": [asdict(x) for x in self.build_results],
            "fuzzer_results": [asdict(x) for x in self.fuzzer_results],
        }
        self.result_json.write_text(
            json.dumps(payload, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

    def _finalize_active_job(
        self,
        session_name: str,
        meta: Dict[str, object],
        status: str,
        note: Optional[str] = None,
        crash_count: int = 0,
        new_crash_files: Optional[List[str]] = None,
    ) -> FuzzerResult:
        job = meta["job"]
        assert isinstance(job, FuzzerJob)

        result = FuzzerResult(
            project=job.project,
            project_index=job.project_index,
            fuzzer=job.fuzzer,
            session_name=session_name,
            log_path=job.log_path,
            status=status,
            started_at=str(meta["started_at"]),
            ended_at=now_str(),
            duration_sec=time.time() - float(meta["start_ts"]),
            crash_count=crash_count,
            new_crash_files=new_crash_files or [],
            note=note,
        )
        return result

    def run_fuzzers_rolling(self, jobs: List[FuzzerJob]) -> None:
        pending: Deque[FuzzerJob] = deque(jobs)
        active: Dict[str, Dict[str, object]] = {}
        total_jobs = len(jobs)
        completed = 0
        launched = 0
        max_parallel = max(1, self.args.max_tmuxs)

        while pending or active:
            if self._stop_requested:
                for session_name, meta in list(active.items()):
                    self.kill_tmux_session(session_name)
                    result = self._finalize_active_job(
                        session_name=session_name,
                        meta=meta,
                        status="stopped",
                        note="stopped by signal",
                    )
                    self.fuzzer_results.append(result)
                    completed += 1
                    del active[session_name]
                self.flush_results_json()
                break

            while pending and len(active) < max_parallel and not self._stop_requested:
                job = pending.popleft()
                session = self.start_tmux_job(job)
                baseline = snapshot_crash_files(Path(job.out_dir), self.args.crash_prefixes)
                active[session] = {
                    "job": job,
                    "session": session,
                    "baseline": baseline,
                    "start_ts": time.time(),
                    "started_at": now_str(),
                }
                launched += 1

            progress_line = (
                f"Fuzz progress: completed {completed}/{total_jobs}, "
                f"running {len(active)}/{max_parallel}, "
                f"queued {len(pending)}, "
                f"launched {launched}/{total_jobs}"
            )
            print("\r" + progress_line + " " * 10, end="", flush=True)

            for session_name, meta in list(active.items()):
                job = meta["job"]
                assert isinstance(job, FuzzerJob)

                start_ts = float(meta["start_ts"])
                duration = time.time() - start_ts
                baseline = meta["baseline"]
                assert isinstance(baseline, set)

                current_crashes = snapshot_crash_files(
                    Path(job.out_dir), self.args.crash_prefixes
                )
                new_crashes = sorted(current_crashes - baseline)

                if new_crashes:
                    self.kill_tmux_session(session_name)
                    crash_count = len(new_crashes)
                    log(f"{job.project} project {job.fuzzer} fuzzer found {crash_count} crashes")
                    result = self._finalize_active_job(
                        session_name=session_name,
                        meta=meta,
                        status="crash",
                        note="new crash artifacts detected in out dir",
                        crash_count=crash_count,
                        new_crash_files=new_crashes,
                    )
                    self.fuzzer_results.append(result)
                    completed += 1
                    del active[session_name]
                    self.flush_results_json()
                    continue

                if duration >= self.args.fuzz_time_sec:
                    self.kill_tmux_session(session_name)
                    result = self._finalize_active_job(
                        session_name=session_name,
                        meta=meta,
                        status="timeout",
                        note=f"exceeded fuzz time limit: {self.args.fuzz_time_hours} hours",
                    )
                    self.fuzzer_results.append(result)
                    completed += 1
                    del active[session_name]
                    self.flush_results_json()
                    continue

                if not tmux_session_exists(session_name):
                    log_tail = tail_text(Path(job.log_path), 80)
                    status = infer_status_from_log(log_tail)
                    note = None
                    crash_count = 0
                    new_crashes = sorted(
                        snapshot_crash_files(Path(job.out_dir), self.args.crash_prefixes) - baseline
                    )

                    if new_crashes:
                        status = "crash"
                        crash_count = len(new_crashes)
                        note = "session exited and crash artifacts were found"

                    result = self._finalize_active_job(
                        session_name=session_name,
                        meta=meta,
                        status=status,
                        note=note,
                        crash_count=crash_count,
                        new_crash_files=new_crashes,
                    )
                    self.fuzzer_results.append(result)
                    completed += 1
                    del active[session_name]
                    self.flush_results_json()
                    continue

            time.sleep(self.args.poll_interval)

        print()

    def run(self) -> int:
        self.register_signal_handlers()
        self.ensure_prerequisites()

        self.projects = self.scan_projects()
        selected_projects = self.select_projects(self.projects)
        if not selected_projects:
            log("No projects found in the given index range. Exiting.")
            return 1

        log(
            f"Discovered {len(self.projects)} projects; selected {len(selected_projects)} projects "
            f"for index range [{self.args.start_index}, {self.args.end_index}] "
            f"(inclusive, default 0-based)."
        )

        total_selected = len(selected_projects)
        build_success = 0
        build_jobs: List[FuzzerJob] = []

        for idx, project in enumerate(selected_projects, start=1):
            if self._stop_requested:
                break

            result = self.build_project(project)
            self.build_results.append(result)

            if result.success:
                build_success += 1
                for fuzzer in result.fuzzers:
                    build_jobs.append(
                        FuzzerJob(
                            project=project.name,
                            project_index=project.index,
                            fuzzer=fuzzer,
                            out_dir=result.out_dir,
                            log_path=str(
                                self.logs_dir / f"{safe_name(project.name)}__{safe_name(fuzzer)}.log"
                            ),
                        )
                    )

            log(f"Build progress: succeeded {build_success}/{idx}, processed {idx}/{total_selected}")
            self.flush_results_json()

        total_fuzzers = len(build_jobs)
        log(
            f"Build stage finished: succeeded projects {build_success}/{total_selected}, "
            f"discovered {total_fuzzers} fuzzers in total."
        )

        if not self._stop_requested and total_fuzzers > 0:
            self.run_fuzzers_rolling(build_jobs)
        elif total_fuzzers == 0:
            log("No runnable fuzzers found. Skipping fuzz stage.")

        self.flush_results_json()

        ok_builds = sum(1 for x in self.build_results if x.success)
        crash_hits = sum(1 for x in self.fuzzer_results if x.crash_count > 0)
        finished = sum(
            1
            for x in self.fuzzer_results
            if x.status in {"finished", "timeout", "crash", "failed", "stopped"}
        )

        log(
            f"All done: build succeeded {ok_builds}/{len(self.build_results)}; "
            f"fuzzers completed {finished}/{len(build_jobs)}; "
            f"jobs with crashes {crash_hits}."
        )
        return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Batch build OSS-Fuzz projects and run fuzzers with tmux rolling-window concurrency."
    )

    parser.add_argument("--repo-root", default=".", help="OSS-Fuzz repository root, default: current directory")
    parser.add_argument("--projects-dir", default="projects", help="projects directory relative to repo-root")
    parser.add_argument("--start-index", type=int, required=True, help="start index (inclusive, default 0-based)")
    parser.add_argument("--end-index", type=int, required=True, help="end index (inclusive, default 0-based)")
    parser.add_argument("--engine", default="libafl", help="engine used by helper.py, default: libafl")
    parser.add_argument("--sanitizer", default="address", help="sanitizer used by helper.py, default: address")
    parser.add_argument(
        "--max-tmuxs",
        type=int,
        default=8,
        help="maximum number of concurrent tmux sessions, default: 8",
    )
    parser.add_argument(
        "--fuzz-time",
        type=float,
        default=72.0,
        help="fuzzing time per target in hours, default: 72",
    )
    parser.add_argument(
        "--poll-interval",
        type=float,
        default=10.0,
        help="polling interval in seconds, default: 10",
    )
    parser.add_argument("--state-dir", default="tmux_fuzz_state", help="directory for logs and JSON outputs")
    parser.add_argument("--scan-json", default="projects_scan.json", help="project scan result JSON filename")
    parser.add_argument("--result-json", default="run_results.json", help="runtime result JSON filename")
    parser.add_argument(
        "--crash-prefixes",
        nargs="+",
        default=list(DEFAULT_CRASH_PREFIXES),
        help="filename prefixes treated as crash artifacts, default: crash- leak- timeout- oom- slow-unit-",
    )

    args = parser.parse_args()

    if args.max_tmuxs <= 0:
        parser.error("--max-tmuxs must be greater than 0")
    if args.fuzz_time <= 0:
        parser.error("--fuzz-time must be greater than 0")
    if args.poll_interval <= 0:
        parser.error("--poll-interval must be greater than 0")

    args.fuzz_time_hours = float(args.fuzz_time)
    args.fuzz_time_sec = int(args.fuzz_time_hours * 3600)
    return args


def main() -> int:
    args = parse_args()
    runner = Runner(args)
    try:
        return runner.run()
    except ManagedProcessError as exc:
        log(f"Error: {exc}")
        return 2
    except subprocess.CalledProcessError as exc:
        log(f"Subprocess execution failed: {exc}")
        return 3


if __name__ == "__main__":
    sys.exit(main())
