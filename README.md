# BlinkUp&trade; Tuner Utility

This utility simplifies the process of tuning the BlinkUp receiver circuit for your imp-based device. 

BlinkUp&trade; uses light and dark pulses, typically from a smartphone screen or an LED, to convey WiFi credentials and provisioning information to an imp. Light levels are detected with a simple circuit which uses a phototransistor and gain resistor to translate light level into a voltage signal. The value of the gain resistor must be carefully selected to acheive the best possibile BlinkUp reliability given your phototransistor and mechanical design. 

This utility collects lightlevel samples during BlinkUp and produces a graph, which can be used to determine how the gain resistor should be adjusted to optimize BlinkUp&trade;. See [How to Tune Your BlinkUp&trade; Circuit](https://electricimp.com/docs/hardware/blinkuptuning/) in the Electric Imp Developer Center.

## Usage

Simply include the utility on both the device and agent side, and the utility will operate as described in the Dev Center article.

#### Agent Code

```Squirrel
#require "BlinkUpTuner.agent.nut:1.0"
```

#### Device Code

```Squirrel
#require "BlinkUpTuner.device.nut:1.0"
```

## License

The NeoPixel class is licensed under the [MIT License](./LICENSE).
