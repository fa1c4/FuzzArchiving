# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################
"""Tests test_all.py"""
import os
import stat
import tempfile
import unittest
from unittest import mock

import test_all


class TestTestAll(unittest.TestCase):
  """Tests for the test_all_function."""

  @mock.patch('test_all.find_fuzz_targets', return_value=[])
  @mock.patch('builtins.print')
  def test_test_all_no_fuzz_targets(self, mock_print, _):
    """Tests that test_all returns False when there are no fuzz targets."""
    outdir = '/out'
    allowed_broken_targets_percentage = 0
    self.assertFalse(
        test_all.test_all(outdir, allowed_broken_targets_percentage))
    mock_print.assert_called_with('ERROR: No fuzz targets found.')

  @mock.patch('test_all.is_elf', return_value=True)
  def test_find_fuzz_targets_libafl_requires_llvm_entrypoint(self, _):
    """Tests that libafl fuzz targets are discovered like libFuzzer targets."""
    with tempfile.TemporaryDirectory() as outdir:
      good_target = os.path.join(outdir, 'good_target')
      bad_target = os.path.join(outdir, 'bad_target')
      with open(good_target, 'wb') as file_handle:
        file_handle.write(b'prefix LLVMFuzzerTestOneInput suffix')
      with open(bad_target, 'wb') as file_handle:
        file_handle.write(b'no fuzz entrypoint here')
      os.chmod(good_target, stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)
      os.chmod(bad_target, stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)

      with mock.patch.dict(os.environ, {'FUZZING_ENGINE': 'libafl'}):
        self.assertEqual([good_target], test_all.find_fuzz_targets(outdir))


if __name__ == '__main__':
  unittest.main()
