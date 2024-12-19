const std = @import("std");
const berlisp = @import("berlisp.zig");

const GCObj = berlisp.memory.GCObj;
const MemoryManager = berlisp.memory.MemoryManager;

/// Окружение - это объект, который связывает имена переменных
/// с их значениями.
///
/// Окружение может хранить в себе ссылку на родительское окружение.
///
/// Мы можем получить доступ к значению по имени, чтобы прочитать или
/// записать переменную.
/// Если не получилось, можно попробовать поискать в родительском
/// окружении.
///
/// Чтобы получить доступ к переменной, её нужно предварительно определить.
/// Иначе будет ошибка.
pub const Environment = struct {
    map: EnvMap,
    next: *GCObj, // всегда Environment

    const EnvMap = std.AutoHashMap([]u8, *GCObj);

    pub fn new(mem_man: *MemoryManager, next: *GCObj) !GCObj { // next - всегда Environment
        const map = EnvMap.init(mem_man.allocator);
        mem_man.makeGCObj(.{ .environment = .{
            .map = map,
            .next = next,
        } });
    }

    pub fn markPropagate(self: Environment) void {
        var iterator = self.map.iterator();
        while (iterator.next()) |val| {
            val.value_ptr.*.recursivelyMarkReachable();
        }
    }

    pub fn prepareToRemove(self: Environment, mem_man: *MemoryManager) void {
        _ = mem_man;
        self.map.deinit();
    }
};

test "create Environment" {
    const mem_man = MemoryManager.init(std.testing.allocator);
    defer mem_man.deleteAll();
}
