# TOML parser

This is a very small change to this [TOML Parser](https://github.com/Up05/toml_parser). The change
is that the `get` function returns an error instead of a boolean, to let the caller know if the value could not be retrieved because the type was wrong, or because the key did not exist. The only modifications were to the `toml.odin` file. 

## Usage changes
the `get` family of functions now looks like this.
```odin
Get_Error :: enum {None, DNE, Type}
get :: proc($T: typeid, section: ^Table, path: ..string) -> (val: T, err: Get_Error) {...}
```