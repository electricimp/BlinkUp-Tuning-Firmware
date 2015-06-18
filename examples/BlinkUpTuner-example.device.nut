// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// BlinkUp Tuning Device Code
// Collects LightLevel samples and sends them to the agent to be graphed

#require "BlinkUpTuner.device.nut:1.0"

agent.on("start", BlinkUpTuner.captureBlinkUp);
