const std = @import("std");
const berlisp = @import("berlisp.zig");

const GCObj = berlisp.memory.GCObj;
const MemoryManager = berlisp.memory.MemoryManager;
const bt = berlisp.base_types;

const EnvError = error{
    VariableIsAlreadyDefined,
    VariableNotDefined,
};

/// Окружение - это объект, который связывает имена переменных
/// с их значениями.
///
/// Окружение может хранить в себе ссылку на родительское окружение.
///
/// Мы можем получить доступ к значению по имени - по символу, чтобы прочитать или
/// записать переменную.
/// Если не получилось, можно попробовать поискать в родительском
/// окружении.
///
/// Чтобы получить доступ к переменной, её нужно предварительно определить.
/// Иначе будет ошибка.
pub const Environment = struct {
    map: EnvMap,
    next: ?*GCObj, // всегда Environment

    /// В этой таблице у нас используются символы в качестве ключей. Я вынужден указать *GCObj
    /// в качестве входного типа, я бы рад указать тип *Symbol, но все символы являются объектами
    /// GCObj и передаются по указателю.
    const EnvMap = std.AutoHashMap(*GCObj, *GCObj);

    pub fn new(mem_man: *MemoryManager, next: ?*GCObj) !*GCObj { // next - всегда Environment
        const map = EnvMap.init(mem_man.allocator);
        return try mem_man.makeGCObj(.{ .environment = .{
            .map = map,
            .next = next,
        } });
    }

    pub fn markPropagate(self: *Environment) void {
        var iterator = self.map.iterator();
        while (iterator.next()) |val| {
            val.value_ptr.*.recursivelyMarkReachable();
        }
    }

    pub fn prepareToRemove(self: *Environment, mem_man: *MemoryManager) void {
        _ = mem_man;
        var map = self.map;
        map.deinit();
    }

    /// Функция позволяет получить из окружения опрделённую переменную.
    /// В качестве ключа должен быть всегда символ!
    /// Какие-то значения передаются по значению, какие-то по ссылке.
    /// Вот тут я не уверен, как правильно сделать: нужно ли возвращать null,
    /// или Лучше вернуть ошибку?
    pub fn takeValBySym(self: *Environment, symbol: *GCObj, mem_man: *MemoryManager) !*GCObj {
        if (self.map.get(symbol)) |val| {
            return try val.take(mem_man);
        }

        if (self.next) |gco| {
            return gco.obj.environment.takeValBySym(symbol, mem_man);
        } else {
            std.debug.print("Этот символ не определён: {s}", .{symbol.obj.symbol.name.obj.str.string});
            return EnvError.VariableNotDefined;
        }
    }

    /// Позволяет определить переменную. Если она уже определена, будет ошибка.
    pub fn def(self: *Environment, symbol: *GCObj, val: *GCObj, mem_man: *MemoryManager) !*GCObj {
        if (self.map.get(symbol)) {
            return EnvError.VariableIsAlreadyDefined;
        }

        const taked_val = val.take(mem_man);

        try self.map.put(symbol, taked_val);

        return taked_val;
    }
};
