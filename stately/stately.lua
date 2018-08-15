local M = {}


local function ensure_hash(v)
	return type(v) == "string" and hash(v) or v
end

--- Create a state machine instance
-- @return The instance
function M.create()
	local instance = {}

	local states = {}
	local events = {}

	local state_change_callbacks = {}
	local enter_state_callbacks = {}
	local leave_state_callbacks = {}
	
	local current_state = nil

	local function invoke_callbacks(callbacks, ...)
		if not callbacks then
			return
		end
		for _,callback in ipairs(callbacks) do
			callback(...)
		end
	end

	--- Create a state
	-- @param name
	-- @return The state instance
	function instance.state(state)
		assert(state, "You must provide a state name")
		state = ensure_hash(state)
		assert(not states[state], ("State %s already exists"):format(state))
		states[state] = { id = state }
		events[state] = {}
		return states[state]
	end

	--- Define a state transition
	-- @param from_state The state to transition from
	-- @param to_state The state to transition to
	-- @param event Event that will trigger the transition
	function instance.transition(from_state, to_state, event)
		assert(from_state, "You must provide a from state")
		assert(states[from_state.id], ("From state %s does not exist"):format(from_state.id))
		assert(to_state, "You must provide a to state")
		assert(states[to_state.id], ("To state %s does not exist"):format(to_state.id))
		assert(event, "You must provide an event name")
		event = ensure_hash(event)
		events[from_state.id][event] = to_state.id
	end


	--- Set a function to be called when transitioning to/entering a specific state
	-- Supports multiple functions
	-- @param state The state to transition to to trigger the callback
	-- @param cb The function to call when transitioning to the state. The function
	-- will receive the previous state as argument as well as any additional
	-- arguments passed with the event that triggered the transition.
	function instance.on_enter(state, cb)
		assert(state, "You must provide a state")
		assert(cb, "You must provide a callback")
		assert(states[state.id], ("State %s does not exist"):format(state.id))
		enter_state_callbacks[state.id] = enter_state_callbacks[state.id] or {}
		table.insert(enter_state_callbacks[state.id], cb)
	end

	
	--- Set a function to be called when transitioning from/leaving a specific state
	-- Supports multiple functions
	-- @param state The state to transition from to trigger the callback
	-- @param cb The function to call when transitioning from the state. The function
	-- will receive the new state as argument as well as any additional
	-- arguments passed with the event that triggered the transition.
	function instance.on_leave(state, cb)
		assert(state, "You must provide a state")
		assert(cb, "You must provide a callback")
		assert(states[state.id], ("State %s does not exist"):format(state.id))
		leave_state_callbacks[state.id] = leave_state_callbacks[state.id] or {}
		table.insert(leave_state_callbacks[state.id], cb)
	end


	--- Set a function to be called when the state changes
	-- Supports multiple functions
	-- @param cb The function to call when a state change occurs. The function
	-- will receive the from and to state as arguments as well as any additional
	-- arguments passed with the event that triggered the transition.
	function instance.on_state_change(cb)
		assert(cb, "You must provide a callback")
		table.insert(state_change_callbacks, cb)
	end


	--- Start the state machine in a specific state
	-- This will invoke any on_enter and on_state callbacks
	-- @param state The state to start the machine in
	function instance.start(state)
		assert(not current_state, "State machine already started")
		assert(state, "You must provide a state")
		assert(states[state.id], ("State %s does not exist"):format(state))
		current_state = state.id
		invoke_callbacks(enter_state_callbacks[state.id], state.id)
		invoke_callbacks(state_change_callbacks, nil, state.id)
	end


	--- Handle an event.
	-- This will transition to a new state if the current state is set
	-- to transition to a new state for the event.
	-- @param event
	function instance.handle_event(event, ...)
		assert(current_state, "State machine not started")
		assert(event, "You must provide an event name")
		event = ensure_hash(event)
		local from_state = current_state
		local to_state = events[from_state][event]
		if not to_state then
			return
		end
		current_state = to_state
		invoke_callbacks(leave_state_callbacks[from_state], to_state, ...)
		invoke_callbacks(enter_state_callbacks[to_state], from_state, ...)
		invoke_callbacks(state_change_callbacks, from_state, to_state, ...)
	end

	--- Get the id of the current state
	-- @return Current state id
	function instance.current_state()
		return current_state
	end

	return instance
end


return M