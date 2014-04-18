# Directory: Wicci/Core/S3_more

## This project is dependent on

* [Wicci Core, C_lib, S0_lib](https://github.com/GregDavidson/wicci-core-S0_lib)

* [Wicci S1_refs](https://github.com/GregDavidson/wicci-core-S1_refs)

* [Wicci S2_core](https://github.com/GregDavidson/wicci-core-S2_core)

## This is a Database Schema of the Wicci System implementing

| Reference Type	| Purpose
|-----------------------|----------
| array_refs	| reference an array of references to objects of any type
| bool_refs	|	reference a single Boolean value
| float_refs	|	reference a single Floating-Point value
| int_refs	|	reference a single Integer value
| text_refs	|	reference a single Text value

Text values can be implemented several different ways.

The values referenced by these types may include context
objects which

* control the formatting of these objects to text
* express the dimensional and unit interpretation of numeric values
