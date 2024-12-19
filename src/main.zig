const std = @import("std");

pub fn main() !void {}

const LispObj = union(enum) {
    symbol: Symbol,
    cons_cell: ConsCell,
    enviroment: Enviroment,
    str: Str,
    number: Number,
};

const MemoryManager = struct {
    last_allocated_object: ?*GCObj,
    allocator: std.mem.Allocator,

    /// Создаёт новый менеджер памяти,
    /// у которого новый, пустой список всех выделенных объектов.
    pub fn new(allocator: std.mem.Allocator) MemoryManager {
        return MemoryManager{
            .last_allocated_object = null,
            .allocator = allocator,
        };
    }

    /// Создаёт в куче новый GCObj из LispObj, добавляет
    /// его в список объектов, созданных данным менеджером памяти.
    pub fn makeGCObj(self: MemoryManager, obj: LispObj) !*GCObj {
        var gco = try self.allocator.create(GCObj);
        gco.obj = obj;
        gco.last_obj = self.last_allocated_object;
        self.last_allocated_object = gco;

        return gco;
    }

    /// Помечает все объекты, созданные данным менеджером
    /// памяти как недостижимые.
    pub fn markAllNotReachable(self: MemoryManager) void {
        var current_obj = self.last_allocated_object;
        while (current_obj) {
            current_obj.mark_not_reachable();
        }
    }
};

const GCObj = struct {
    last_obj: ?*GCObj,
    is_reachable: bool,
    obj: LispObj,

    /// Помечает объект достижимым, рекурсивно
    /// помечает все объекты, на которые ссылается данный.
    pub fn recursivelyMarkReachable(obj: *GCObj) void {
        obj.is_reachable = true;
        switch (obj.obj) {
            .symbol => |sym| {
                sym.markPropogate();
            },
            .cons_cell => |cell| {
                cell.markPropogate();
            },
            .str => |str| {
                str.markPropogate();
            },

            .number => {},
        }
    }

    /// Помечает объект, как недостижимый.
    pub fn markNotReachable(self: *GCObj) void {
        self.is_reachable = false;
    }

    /// Эта функция удаляет GCObj.
    /// При этом, она не занимается поддержанием списка всех
    /// объектов. Если использовать эту функцию неправильно,
    /// может оборваться список всех объектов.
    pub fn delete(gco: *GCObj, mem_man: MemoryManager) void {
        switch (gco.obj) {
            .symbol => |sym| {
                sym.prepareToRemove(mem_man);
            },
            .cons_cell => |cell| {
                cell.prepareToRemove(mem_man);
            },
            .str => |str| {
                str.prepareToRemove(mem_man);
            },
            .number => {}, // Числа передаются по значению.
            .enviroment => |env| {
                env.prepareToRemove(mem_man);
            },
        }

        mem_man.allocator.destroy(gco);
    }
};

const ConsCell = struct {
    car: *GCObj,
    cdr: *GCObj,

    pub fn markPropogate(self: ConsCell) void {
        self.car.recursivelyMarkReachable();
        self.cdr.recursivelyMarkReachable();
    }

    pub fn prepareToRemove(self: ConsCell, mem_man: MemoryManager) void {
        _ = self;
        _ = mem_man;
    }
};

const Symbol = struct {
    name: *GCObj, // Str

    pub fn new(mem_man: MemoryManager, name: []u8) !*GCObj {
        const name_str = Str.new(mem_man, name);
        return try mem_man.makeGCObj(.{ .symbol = .{ .name = name_str } });
    }

    pub fn fromStr(mem_man: MemoryManager, str: Str) !*GCObj {
        return try mem_man.makeGCObj(.{ .symbol = .{ .name = str } });
    }

    pub fn markPropogate(self: Symbol) void {
        self.name.recursivelyMarkReachable();
    }

    pub fn prepareToRemove(self: Symbol, mem_man: MemoryManager) void {
        _ = self;
        _ = mem_man;
    }
};

const Str = struct {
    string: []u8,

    pub fn new(mem_man: MemoryManager, str: []u8) *GCObj {
        const str_mem = mem_man.allocator.alloc(u8, str.len);
        std.mem.copyForwards(u8, str_mem, str);

        return try mem_man.makeGCObj(.{ .str = str_mem });
    }

    pub fn markPropogate(self: Str) void {
        _ = self;
    }

    pub fn prepareToRemove(self: Str, mem_man: MemoryManager) void {
        mem_man.allocator.free(self.string);
    }
};

const Enviroment = struct {
    map: EnvMap,
    next: *GCObj, // всегда Enviroment

    const EnvMap = std.AutoHashMap([]u8, *GCObj);

    pub fn new(mem_man: MemoryManager, next: *GCObj) !GCObj { // next - всегда Enviroment
        const map = EnvMap.init(mem_man.allocator);
        mem_man.makeGCObj(.{ .enviroment = .{
            .map = map,
            .next = next,
        } });
    }

    pub fn markPropagate(self: Enviroment) void {
        var iterator = self.map.iterator();
        while (iterator.next()) |val| {
            val.value_ptr.*.recursivelyMarkReachable();
        }
    }

    pub fn prepareToRemove(self: Enviroment, mem_man: MemoryManager) void {
        _ = mem_man;
        self.map.deinit();
    }
};

/// Число. Над ним можно производить арифметические операции.
/// Может быть либо с плавающей точкой, либо целым.
/// Если одно число было с плавающей точкой, то результат операции тоже
/// будет таким.
///
/// Числа передаются не по ссылке, а по значению.
const Number = union(enum) {
    int: i64,
    double: f64,

    pub fn add(num_1: Number, num_2: Number) Number {
        return switch (num_1) {
            .double => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = val_1 + val_2 },
                    .int => |val_2| Number{ .int = val_1 + @as(f64, val_2) },
                }
            },
            .int => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = @as(f64, val_1) + val_2 },
                    .int => |val_2| Number{ .int = val_1 + val_2 },
                }
            },
        };
    }

    pub fn sub(num_1: Number, num_2: Number) Number {
        return switch (num_1) {
            .double => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = val_1 - val_2 },
                    .int => |val_2| Number{ .int = val_1 - @as(f64, val_2) },
                }
            },
            .int => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = @as(f64, val_1) - val_2 },
                    .int => |val_2| Number{ .int = val_1 - val_2 },
                }
            },
        };
    }

    pub fn mul(num_1: Number, num_2: Number) Number {
        return switch (num_1) {
            .double => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = val_1 * val_2 },
                    .int => |val_2| Number{ .int = val_1 * @as(f64, val_2) },
                }
            },
            .int => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = @as(f64, val_1) * val_2 },
                    .int => |val_2| Number{ .int = val_1 * val_2 },
                }
            },
        };
    }

    pub fn div(num_1: Number, num_2: Number) Number {
        return switch (num_1) {
            .double => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = val_1 / val_2 },
                    .int => |val_2| Number{ .int = val_1 / @as(f64, val_2) },
                }
            },
            .int => |val_1| {
                switch (num_2) {
                    .double => |val_2| Number{ .double = @as(f64, val_1) / val_2 },
                    .int => |val_2| if (val_1 % val_2 == 0)
                        val_1 / val_2
                    else
                        @as(f64, val_1) / @as(f64, val_2),
                }
            },
        };
    }
};
