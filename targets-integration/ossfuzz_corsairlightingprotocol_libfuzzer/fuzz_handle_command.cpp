// fuzz_handle_command.cpp
#include <stdint.h>
#include <stddef.h>
#include <string.h>

#include "CorsairLightingProtocol.h"

// ----------- Simple Response stub -----------

class FuzzResponse : public CorsairLightingProtocolResponse {
public:
    // Implementations of send()/sendError()/send_P() in the base class ultimately 
    // call sendX, so we only need to implement sendX.
    void sendX(const uint8_t* data, const size_t x) const override {
        // Read some data to prevent it from being completely optimized away
        if (x > 0 && data != nullptr) {
            volatile uint8_t sink = data[0];
            (void)sink;
        }
    }

    // Optional: Override these to call sendX directly, 
    // ensuring the code compiles even if you don't link CorsairLightingProtocolResponse.cpp.
    void send(const uint8_t* data, size_t size) const override {
        sendX(data, size);
    }

    void sendError() const override {
        uint8_t err = PROTOCOL_RESPONSE_ERROR;
        sendX(&err, 1);
    }

    void send_P(const uint8_t* data, size_t size) const override {
        // On real AVR, this reads from PROGMEM; in the fuzzing environment, we treat it as a standard pointer.
        sendX(data, size);
    }
};

// ----------- LED Controller stub (inherits from LEDController to preserve parsing logic) -----------

class FuzzLEDController : public LEDController {
public:
    FuzzLEDController() {
        // Initialize internal state
        reset();
    }

protected:
    // Allocate a small buffer for each channel to store LED values, preventing out-of-bounds access from fuzz data.
    static constexpr size_t kMaxLedsPerChannel = 128;
    CRGB leds[CHANNEL_NUM][kMaxLedsPerChannel];

    void triggerLEDUpdate() override {
        // Simple array access to avoid optimization
        volatile uint8_t r = leds[0][0].r;
        (void)r;
    }

    void setLEDExternalTemperature(uint8_t channel, uint16_t temp) override {
        // Do nothing here, just ensure no crashes occur
        (void)channel;
        (void)temp;
    }

    void setLEDColorValues(uint8_t channel,
                           uint8_t color,
                           uint8_t offset,
                           const uint8_t* values,
                           size_t len) override {
        if (channel >= CHANNEL_NUM || values == nullptr)
            return;
        if (offset >= kMaxLedsPerChannel)
            return;

        size_t maxCopy = kMaxLedsPerChannel - offset;
        if (len > maxCopy)
            len = maxCopy;

        for (size_t i = 0; i < len; ++i) {
            uint8_t v = values[i];
            CRGB& pix = leds[channel][offset + i];
            switch (color % 3) {
            case 0: pix.r = v; break;
            case 1: pix.g = v; break;
            case 2: pix.b = v; break;
            }
        }
    }

    void clearLEDColorValues(uint8_t channel) override {
        if (channel >= CHANNEL_NUM)
            return;
        for (size_t i = 0; i < kMaxLedsPerChannel; ++i) {
            leds[channel][i] = CRGB(); // Clear to zero
        }
    }

    uint8_t getLEDAutodetectionResult(uint8_t channel) override {
        // Just return a simple value
        return (channel < CHANNEL_NUM) ? 0 : 0xFF;
    }

    bool save() override {
        // Do not perform real EEPROM writes; simply return true
        return true;
    }

    bool load() override {
        // Do not perform real EEPROM reads
        return true;
    }
};

// ----------- Fan / Temperature stub (executes code paths without performing actions) -----------

class FuzzTemperatureController : public ITemperatureController {
public:
    void handleTemperatureControl(const Command& command,
                                  const CorsairLightingProtocolResponse* response) override {
        // Simply return an error response to ensure the path is executed
        if (response) {
            response->sendError();
        }
        (void)command;
    }
};

class FuzzFanController : public IFanController {
public:
    void handleFanControl(const Command& command,
                          const CorsairLightingProtocolResponse* response) override {
        if (response) {
            response->sendError();
        }
        (void)command;
    }
};

// ----------- Global singletons to maintain state across inputs -----------

// Note: These global objects are reused repeatedly during fuzzing.
// This simulates the receipt of consecutive commands, which is a valid use case for the protocol.
static FuzzLEDController g_ledController;

// Fix a DeviceID; any value will suffice
static DeviceID g_deviceId = { { 0x01, 0x23, 0x45, 0x67 } };
static CorsairLightingFirmwareStorageStatic g_fwStorage(g_deviceId);

// Select any product here, e.g., Lighting Node PRO
static CorsairLightingFirmware g_firmware(CORSAIR_LIGHTING_NODE_PRO, &g_fwStorage);

// Temperature / Fan stubs
static FuzzTemperatureController g_tempController;
static FuzzFanController         g_fanController;

// Use the constructor that includes temperature and fan controllers so all branches of handleCommand are exercised.
static CorsairLightingProtocolController g_controller(
    &g_ledController,
    &g_tempController,
    &g_fanController,
    &g_firmware
);

// ----------- fuzz entrypoint -----------

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size == 0 || data == nullptr) {
        return 0;
    }

    FuzzResponse response;

    Command cmd{};
    // Command.raw size is COMMAND_SIZE (64 bytes); extra data can be discarded
    size_t toCopy = size;
    if (toCopy > sizeof(cmd.raw)) {
        toCopy = sizeof(cmd.raw);
    }
    memcpy(cmd.raw, data, toCopy);

    // Hand over to the protocol controller for processing
    g_controller.handleCommand(cmd, &response);

    return 0;
}
