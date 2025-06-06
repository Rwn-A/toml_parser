package toml

import "core:strings"
import "core:os"
import "base:intrinsics"
import "base:runtime"
import "dates"

import "core:fmt"

log     :: fmt.print
logf    :: fmt.printf
logln   :: fmt.println

assertf :: fmt.assertf

Builder        :: strings.Builder
b_destroy      :: strings.builder_destroy
b_reset        :: strings.builder_reset
b_write_string :: strings.write_string
b_printf       :: fmt.sbprintf

// Parses the file. You can use print_error(err) for error messages.
parse_file :: proc(filename: string, allocator := context.allocator) -> (section: ^Table, err: Error) {
    context.allocator = allocator
    blob, ok_file_read := os.read_entire_file_from_filename(filename)
    if !ok_file_read {
        err.type = .Bad_File
        b_write_string(&err.more, filename)
        return nil, err
    }

    section, err = parse(string(blob), filename, allocator)
    delete_slice(blob)
    return
}

// This is made to be used with default, err := #load(filename). original_filename is only used for errors.
parse_data :: proc(data: []u8, original_filename := "untitled data", allocator := context.allocator) -> (section: ^Table, err: Error) {
    return parse(string(data), original_filename, allocator)
}

// Frees all of the memory allocated by the parser for a particular type
// It is recursive, so you can just give it the root Table.
deep_delete :: proc(type: Type, allocator := context.allocator) -> (err: runtime.Allocator_Error) {
    context.allocator = allocator
    #partial switch value in type {
    case ^List:
        if value == nil do break
        for &item in value { 
            err = deep_delete(item, allocator); 
            if err != .None do return
        }
        err = delete_dynamic_array(value^)
        if err == .None do free(value)

    case ^Table:
        if value == nil do break
        for k, &v in value { 
            err = delete_string(k); 
            if err != .None do return 
            err = deep_delete(v, allocator); 
            if err != .None do return 
        }
        err = delete_map(value^)
        if err == .None do free(value)

    case string:
        err = delete_string(value)
    }
    return
}

// Retrieves and type checks the value at path. The last element of path is the actual key.
// section may be any Table.

Get_Error :: enum {None, DNE, Type}
get :: proc($T: typeid, section: ^Table, path: ..string) -> (val: T, err: Get_Error)
    where intrinsics.type_is_variant_of(Type, T)
{
    assert(len(path) > 0, "You must specify at least one path str in toml.fetch()!")
	if section == nil {
		return val, .DNE
	}

    section := section
    for dir in path[:len(path) - 1] {
        if dir in section {
            section, ok := section[dir].(^Table)
            if !ok do return val, .DNE
        } else do return val, .DNE
    }
    last := path[len(path) - 1]
    if last in section {
        if val, ok := section[last].(T); ok {
            return val, .None
        }
        return val, .Type
    }
    return val, .DNE
}

// Also retrieves and typechecks the value at path, but if something goes wrong, it crashes the program.
get_panic :: proc($T: typeid, section: ^Table, path: ..string) -> T
    where intrinsics.type_is_variant_of(Type, T)
{
    assert(len(path) > 0, "You must specify at least one path str in toml.fetch_panic()!")
    section := section
    for dir in path[:len(path) - 1] {
        assertf(dir in section, "Missing key: '%s' in table '%v'!", path, section^)
        section = section[dir].(^Table)
    }
    last := path[len(path) - 1]
    assertf(last in section, "Missing key: '%s' in table '%v'!", last, section^)
    return section[last].(T)
}

// Currently(2024-06-__), Odin hangs if you simply fmt.print Table
print_table :: proc(section: ^Table, level := 0) {
    log("{ ")
    i := 0
    for k, v in section {
        log(k, "= ") 
        print_value(v, level)
        if i != len(section) - 1 do log(", ")
        else do log(" ")
        i += 1
    }
    log("}")
    if level == 0 do logln()
}

@(private="file")
print_value :: proc(v: Type, level := 0) {
    #partial switch t in v {
    case ^Table:
        print_table(t, level + 1)
    case ^[dynamic] Type:
        log("[ ")
        for e, i in t {
            print_value(e, level)
            if i != len(t) - 1 do log(", ")
            else do log(" ")
        }
        log("]")
    case string:
        logf("%q", v)
    case:
        log(v)
    }
}

// Here lies the code for LSP:
get_i64    :: proc(section: ^Table, path: ..string) -> 
            (val: i64, err: Get_Error) { return get(i64, section, ..path) }
get_f64    :: proc(section: ^Table, path: ..string) -> 
            (val: f64, err: Get_Error) { return get(f64, section, ..path) }
get_bool   :: proc(section: ^Table, path: ..string) -> 
            (val: bool, err: Get_Error) { return get(bool, section, ..path) }
get_string :: proc(section: ^Table, path: ..string) -> 
            (val: string, err: Get_Error) { return get(string, section, ..path) }
get_date   :: proc(section: ^Table, path: ..string) -> 
            (val: dates.Date, err: Get_Error) { return get(dates.Date, section, ..path) }
get_list   :: proc(section: ^Table, path: ..string) -> 
            (val: ^List, err: Get_Error) { return get(^List, section, ..path) } 
get_table  :: proc(section: ^Table, path: ..string) -> 
            (val: ^Table, err: Get_Error) { return get(^Table, section, ..path) }

get_i64_panic    :: proc(section: ^Table, path: ..string) -> 
            i64 { return get_panic(i64, section, ..path) }
get_f64_panic    :: proc(section: ^Table, path: ..string) -> 
            f64 { return get_panic(f64, section, ..path) }
get_bool_panic   :: proc(section: ^Table, path: ..string) -> 
            bool { return get_panic(bool, section, ..path) }
get_string_panic :: proc(section: ^Table, path: ..string) -> 
            string { return get_panic(string, section, ..path) }
get_date_panic   :: proc(section: ^Table, path: ..string) -> 
            dates.Date { return get_panic(dates.Date, section, ..path) }
get_list_panic   :: proc(section: ^Table, path: ..string) -> 
            ^List { return get_panic(^List, section, ..path) } 
get_table_panic  :: proc(section: ^Table, path: ..string) -> 
            ^Table { return get_panic(^Table, section, ..path) }

