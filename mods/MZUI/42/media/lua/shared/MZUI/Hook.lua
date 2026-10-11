MZUI = MZUI or {}

-- Reversible monkey-patching. Every patch/event/cleanup is recorded on a scope;
-- dispose() undoes them in reverse order, checking identity before restoring so
-- a vanilla change made after (or by another mod) is never clobbered. Scopes
-- nest: a child scope adds to its parent's list, dispose cascades.
--
-- Kahlua restriction: a Lua function value cannot carry fields ("attempted
-- index: mzHook of non-table"), so owned wrappers are identified through the
-- side-registry Hook.wrapped below, never by tagging the function itself.
local Hook = MZUI.Hook or {}
MZUI.Hook = Hook

-- target -> key -> wrapper we installed (for cross-scope chain detection).
-- ResetLua re-executes Hook.lua without clearing the game's Lua environment,
-- so the previous run's registry would still describe wrappers whose closures
-- were torn down with the old class tables; drop it on every re-load so the
-- fresh patches start with a clean slate.
if Hook.wrapped ~= nil then
    Hook.wrapped = nil
end
Hook.wrapped = {}

local function markWrapped(target, key, fn)
    Hook.wrapped[target] = Hook.wrapped[target] or {}
    Hook.wrapped[target][key] = fn
end

local function unmarkWrapped(target, key)
    local perTarget = Hook.wrapped[target]
    if perTarget then perTarget[key] = nil end
end

function Hook.isWrapped(target, key)
    local perTarget = Hook.wrapped[target]
    return perTarget ~= nil and perTarget[key] ~= nil
end

-- Whether Hook:patch would accept this slot now (queries the same registry).
function Hook.isSafeToPatch(target, key)
    return not Hook.isWrapped(target, key)
end

Hook.__index = Hook

function Hook.new(parent)
    local scope = setmetatable({
        parent = parent,
        entries = {},
        children = {},
        disposed = false,
    }, Hook)
    if parent then
        table.insert(parent.children, scope)
    end
    return scope
end

function Hook:record(undo)
    table.insert(self.entries, undo)
    return undo
end

-- Replace target[key] with fn. Re-patching a slot MZUI already owns is
-- allowed (self has a fresh scope; the old scope must dispose first); a slot
-- owned by a live sibling scope errors so double-patches surface loudly.
function Hook:patch(target, key, fn)
    assert(target ~= nil and key ~= nil, "patch target required")
    assert(fn ~= nil, "patch replacement required")
    if Hook.isWrapped(target, key) then
        error("patch target already patched by MZUI (live scope): " .. tostring(key))
    end
    local original = target[key]
    target[key] = fn
    markWrapped(target, key, fn)
    return self:record(function()
        -- Identity-checked: undo only when the slot still holds our wrapper
        -- (pzopt or a hot reload may have replaced it since).
        if target[key] == fn then
            target[key] = original
            unmarkWrapped(target, key)
        end
    end)
end

function Hook:event(events, name, fn)
    assert(events ~= nil and type(events.Add) == "function",
        "event table required (got " .. tostring(events) .. ")")
    events.Add(events, fn)
    return self:record(function()
        if events.Remove then events.Remove(events, fn) end
    end)
end

-- Suspend a vanilla event handler while wrapped: the original listener table
-- entry is removed and restored on dispose (used for reimplemented handlers).
function Hook:suspendEvent(events, name)
    assert(events ~= nil and events[name] ~= nil, "event not found")
    local original = events[name]
    events[name] = nil
    return self:record(function()
        if events[name] == nil then
            events[name] = original
        end
    end)
end

function Hook:child()
    return Hook.new(self)
end

function Hook:defer(fn)
    return self:record(fn)
end

function Hook:isDisposed()
    return self.disposed
end

function Hook:dispose()
    if self.disposed then return end
    self.disposed = true
    for _, child in ipairs(self.children) do child:dispose() end
    self.children = {}
    for i = #self.entries, 1, -1 do
        local ok, err = pcall(self.entries[i])
        if not ok and type(print) == "function" then
            print("[MZUI] hook dispose error: " .. tostring(err))
        end
    end
    self.entries = {}
end

return Hook
