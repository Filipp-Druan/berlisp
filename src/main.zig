const std = @import("std");

pub fn main() !void {}

const LispObj = union(enum) {
    symbol: Symbol,
    cons_cell: ConsCell,
    enviroment: Enviroment,
};

const RCObj = struct {
    ref_counter: isize,
    obj: LispObj,

    pub fn new(allocator: std.mem.Allocator, obj: LispObj) !*RCObj {
        var rco = try allocator.create(RCObj);

        rco = .{ .ref_counter = 1, .obj = obj };

        return rco;
    }

    pub fn getReference(self: *RCObj) *RCObj {
        self.ref_counter += 1;
        return self;
    }

    // Некоторые объекты передаются по ссылке, а некоторые копируются.
    // Когда можно использовать эту функцию?
    // 1) При передачи объекта в функцию.
    // 2) При присваивании, или получаении значения переменной.
    pub fn take(self: *RCObj, allocator: std.mem.Allocator) *RCObj {
        switch (self.obj) {
            .symbol => {
                return self.getReference();
            },
            .cons_cell => {
                return self.getReference();
            },
            .enviroment => {
                return self.getReference();
            },
        }
        _ = allocator;
    }

    pub fn deleteReference(self: *RCObj, allocator: std.mem.Allocator) void {
        self.ref_counter -= 1;
        if (self.ref_counter == 0) {
            switch (self.obj) {
                .symbol => |sym| {
                    sym.prepareToRemove(allocator);
                    allocator.destroy(self);
                },
                .cons_cell => |cell| {
                    cell.prepareToRemove(allocator);
                    allocator.destroy(self);
                },
                .enviroment => |env| {
                    env.prepareToRemove(allocator);
                    allocator.destroy(self);
                },
            }
        }
    }
};

const ConsCell = struct {
    car: *RCObj,
    cdr: *RCObj,

    fn new(allocator: std.mem.Allocator, car: *RCObj, cdr: *RCObj) !*RCObj {
        return RCObj.new(allocator, .{ .cons_cell = .{ .car = car, .cdr = cdr } });
    }

    fn prepareToRemove(self: ConsCell, allocator: std.mem.Allocator) void {
        self.car.deleteReference(allocator);
        self.cdr.deleteReference(allocator);
    }
};

const Symbol = struct {
    name: []const u8,

    fn new(allocator: std.mem.Allocator, name: []const u8) !*RCObj {
        const name_memory = try allocator.alloc(u8, name.len);
        std.mem.copyForwards(u8, name_memory, name);

        const rco = try RCObj.new(allocator, .{
            .symbol = .{ .name = name_memory },
        });

        return rco;
    }

    fn prepareToRemove(self: Symbol, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

const Enviroment = struct {
    map: EnvMap,
    parent: RCObj, // В этом объекте обязательно должно быть другое окружение.

    const EnvMap = std.AutoHashMap(
        []u8,
        *RCObj,
    );

    const EnvError = error{
        VariableUndefined,
        VariableDefined,
    };

    pub fn new(allocator: std.mem.Allocator, parent: RCObj) !*RCObj {
        var env = try allocator.create(Enviroment);
        const map = EnvMap.init(allocator);
        env = .{ .map = map, .parent = parent };

        return try RCObj.new(allocator, .{ .enviroment = env });
    }

    pub fn prepareToRemove(self: Enviroment, allocator: std.mem.Allocator) void {
        const iter = self.map.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deleteReference(allocator);
        }
        self.map.deinit();
        self.parent.deleteReference(allocator);
    }

    pub fn lookup(self: Enviroment, sym: Symbol) *RCObj {
        const res = self.map.get(sym.name);
        if (res) |obj| {
            return obj.getReference();
        } else {
            return res;
        }
    }

    pub fn setVar(self: Enviroment, allocator: std.mem.Allocator, var_symbol: Symbol, value: *RCObj) EnvError!void {
        if (self.map.get(var_symbol.name)) |last_val| {
            last_val.deleteReference(allocator);
            self.map.put(var_symbol.name, value.getReference());
        } else {
            return EnvError.VariableUndefined;
        }
    }

    pub fn defVar(self: Enviroment, var_symbol: Symbol, value: *RCObj) !void {
        if (self.map.get(var_symbol.name)) {
            return EnvError.VariableDefined;
        } else {}
    }
};

test "Создаём и удаляем объекты, ищем утечки памяти" {
    const allocator = std.testing.allocator;
    const sym_1 = try Symbol.new(allocator, "Hello!");
    const sym_2 = try Symbol.new(allocator, "Friends!p");
    var list = try ConsCell.new(allocator, sym_1, sym_2);
    list.deleteReference(allocator);
}
