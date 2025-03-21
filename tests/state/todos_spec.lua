local dooing_state = require("dooing.state")
local todos = require("dooing.state.todos")
local config = require("dooing.config")

describe("todos", function()
    before_each(function()
        -- Set up test state
        dooing_state.todos = {}
        dooing_state.deleted_todos = {}
        dooing_state.MAX_UNDO_HISTORY = 10
        dooing_state.save_to_disk = function() end -- Mock save_to_disk
        
        -- Mock vim.notify
        _G._original_vim_notify = vim.notify
        vim.notify = function() end
    end)

    after_each(function()
        -- Restore original functions
        vim.notify = _G._original_vim_notify
    end)

    it("should add a todo", function()
        dooing_state.add_todo("Test todo", {})
        
        assert.are.equal(1, #dooing_state.todos)
        assert.are.equal("Test todo", dooing_state.todos[1].text)
        assert.are.equal(false, dooing_state.todos[1].done)
    end)

    it("should parse categories from tags", function()
        dooing_state.add_todo("Test todo with #category tag", {})
        
        assert.are.equal("category", dooing_state.todos[1].category)
    end)

    it("should toggle todo status correctly", function()
        dooing_state.add_todo("Test todo", {})
        
        -- Initial state
        assert.are.equal(false, dooing_state.todos[1].done)
        assert.are.equal(false, dooing_state.todos[1].in_progress)
        
        -- First toggle: pending -> in_progress
        dooing_state.toggle_todo(1)
        assert.are.equal(false, dooing_state.todos[1].done)
        assert.are.equal(true, dooing_state.todos[1].in_progress)
        
        -- Second toggle: in_progress -> done
        dooing_state.toggle_todo(1)
        assert.are.equal(true, dooing_state.todos[1].done)
        assert.are.equal(false, dooing_state.todos[1].in_progress)
        
        -- Third toggle: done -> pending
        dooing_state.toggle_todo(1)
        assert.are.equal(false, dooing_state.todos[1].done)
        assert.are.equal(false, dooing_state.todos[1].in_progress)
    end)
    
    it("should delete a todo", function()
        -- Add and then delete a todo
        dooing_state.add_todo("Test todo", {})
        dooing_state.delete_todo(1)
        
        assert.are.equal(0, #dooing_state.todos)
        assert.are.equal(1, #dooing_state.deleted_todos)
    end)

    it("should delete completed todos", function()
        -- Add three todos, complete one
        dooing_state.add_todo("Todo 1", {})
        dooing_state.add_todo("Todo 2", {})
        dooing_state.add_todo("Todo 3", {})
        
        dooing_state.toggle_todo(2) -- Make it in_progress
        dooing_state.toggle_todo(2) -- Make it done
        
        dooing_state.delete_completed()
        
        assert.are.equal(2, #dooing_state.todos)
        assert.are.equal("Todo 1", dooing_state.todos[1].text)
        assert.are.equal("Todo 3", dooing_state.todos[2].text)
    end)

    it("should undo deleted todos", function()
        -- Add and delete a todo
        dooing_state.add_todo("Test todo", {})
        dooing_state.delete_todo(1)
        
        -- Verify it's gone
        assert.are.equal(0, #dooing_state.todos)
        
        -- Undo the delete
        local result = dooing_state.undo_delete()
        
        -- Verify it's back
        assert.is_true(result)
        assert.are.equal(1, #dooing_state.todos)
        assert.are.equal("Test todo", dooing_state.todos[1].text)
        assert.are.equal(0, #dooing_state.deleted_todos)
    end)

    it("should limit undo history size", function()
        -- Add 15 todos
        for i = 1, 15 do
            dooing_state.add_todo("Todo " .. i, {})
        end
        
        -- Delete all 15
        for i = 15, 1, -1 do
            dooing_state.delete_todo(i)
        end
        
        -- Verify undo history is limited to MAX_UNDO_HISTORY
        assert.are.equal(dooing_state.MAX_UNDO_HISTORY, #dooing_state.deleted_todos)
    end)

    it("should remove duplicates", function()
        -- Setup for gen_hash mock (simplified version that just uses the text)
        local original_vim_inspect = vim.inspect
        vim.inspect = function(obj) return obj.text end
        
        local original_vim_fn_sha256 = vim.fn.sha256
        vim.fn.sha256 = function(str) return str end
        
        -- Add duplicate todos
        dooing_state.add_todo("Duplicate todo", {})
        dooing_state.add_todo("Unique todo", {})
        dooing_state.add_todo("Duplicate todo", {})
        
        local removed = dooing_state.remove_duplicates()
        
        -- Verify duplicates are removed
        assert.are.equal("1", removed) -- returns string
        assert.are.equal(2, #dooing_state.todos)
        
        -- Restore original functions
        vim.inspect = original_vim_inspect
        vim.fn.sha256 = original_vim_fn_sha256
    end)
end)