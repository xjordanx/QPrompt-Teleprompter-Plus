// SPDX-License-Identifier: GPL-3.0-only
// Intelliprompter: gamepad input interface (deferred feature, see CLAUDE.md §7).
//
// The SDL3-backed implementation is compiled only with -DINTELLIPROMPTER_GAMEPAD=ON.
// The curve helper below is pure so it can be unit-tested without a controller.

#pragma once

#include <algorithm>
#include <cmath>
#include <functional>

namespace intelliprompter::input {

enum class GamepadAction {
    PauseResume,
    NextMarker,
    PrevMarker,
    MarkCovered,
    UnmarkCovered,
    SkipBlock,
    NudgeUp,
    NudgeDown,
};

struct StickCurve {
    float deadzone = 0.12f; // fraction of full travel ignored around centre
    float expo = 2.0f;      // 1 = linear, >1 = finer control near centre
};

// Maps a raw axis value in [-1, 1] to [-1, 1] with a rescaled deadzone and an
// exponential response. Outside the deadzone the output starts from 0, so there is
// no jump at the deadzone edge.
inline float applyStickCurve(float raw, const StickCurve &curve)
{
    const float v = std::clamp(raw, -1.0f, 1.0f);
    const float mag = std::fabs(v);
    if (mag <= curve.deadzone || curve.deadzone >= 1.0f)
        return 0.0f;
    const float scaled = (mag - curve.deadzone) / (1.0f - curve.deadzone);
    const float shaped = std::pow(scaled, std::max(curve.expo, 1.0f));
    return v < 0.0f ? -shaped : shaped;
}

class GamepadInput
{
public:
    virtual ~GamepadInput() = default;

    virtual bool start() = 0; // opens the first available controller; false if none / unavailable
    virtual void stop() = 0;
    virtual void poll() = 0;  // pump events; call from a Qt timer (~120 Hz)

    // Continuous scroll demand in [-1, 1] after the stick curve; mapped onto
    // QPrompt's velocity steps by the integration layer.
    std::function<void(float)> onScrollDemand;
    std::function<void(GamepadAction)> onAction;
    std::function<void(bool connected)> onConnectionChanged;
};

} // namespace intelliprompter::input
