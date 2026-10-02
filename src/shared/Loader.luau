--!strict
-- Boots a folder of modules (server services or client controllers) in two
-- phases. Every module's Init runs first, in name order, so modules can set up
-- state that others read. Then every module's Start runs in its own thread, for
-- loops and event connections. An error in Init stops the boot so it gets noticed.

type Lifecycle = {
	Init: ((self: Lifecycle) -> ())?,
	Start: ((self: Lifecycle) -> ())?,
}

local Loader = {}

function Loader.boot(folder: Instance?): number
	if folder == nil then
		return 0
	end

	local children = folder:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)

	local modules: { Lifecycle } = {}
	for _, child in children do
		if child:IsA("ModuleScript") then
			table.insert(modules, require(child) :: any)
		end
	end

	for _, module in modules do
		local init = module.Init
		if init then
			init(module)
		end
	end

	for _, module in modules do
		local start = module.Start
		if start then
			task.spawn(start, module)
		end
	end

	return #modules
end

return Loader
