/*
 * Copyright (C) Photon Vision.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma once

#include <string>
#include <string_view>
#include <vector>

enum CameraModel {
    Disconnected = 0,
    OV5647, // Picam v1
    IMX219, // Picam v2
    IMX708, // Picam v3
    IMX477, // Picam HQ
    OV9281,
    OV7251,
    Unknown,
    // Models below are only known to this library. PhotonVision's Java
    // SensorModel enum mirrors the values above by ordinal, so these must stay
    // after Unknown and be reported through toJavaSensorModel().
    OV9782, // Colour version of the OV9281 (Raze)
};
CameraModel stringToModel(std::string_view model);
bool isGrayScale(CameraModel model);
// The model PhotonVision's SensorModel enum should see. The OV9782 is
// reported as an OV9281: same 1280x800 global shutter sensor and video modes
// (libcamera's Raspberry Pi IPA aliases its camera helper the same way).
CameraModel toJavaSensorModel(CameraModel model);
