-- The Luau spec runner. test.project.json maps tests/luau to ServerStorage.LootGoblinsTests (never into play builds),
-- and dev.ps1 serves that project. Run in Studio's EDIT mode (command bar or Studio MCP execute_luau):
--   print(require(game.ServerStorage.LootGoblinsTests.Runner).run().summary)
-- Specs only require pure modules (no remotes, DataStores or players), so they cannot disturb a running game.
-- Each Specs/<Name>.lua returns function(t), using t.test(name, fn), t.ok(condition, message), t.eq(actual, expected).
local Runner = {}

function Runner.run()
	local results = { passed = 0, failed = 0, failures = {}, names = {} }
	local t = {}
	function t.ok(condition, message)
		if not condition then
			error(message or "expected true", 2)
		end
	end
	function t.eq(actual, expected, message)
		if actual ~= expected then
			error(
				string.format(
					"%s: expected %s, got %s",
					message or "values differ",
					tostring(expected),
					tostring(actual)
				),
				2
			)
		end
	end
	function t.test(name, fn)
		local ok, err = pcall(fn)
		if ok then
			results.passed += 1
		else
			results.failed += 1
			table.insert(results.failures, name .. ": " .. tostring(err))
		end
		table.insert(results.names, (ok and "PASS " or "FAIL ") .. name)
	end
	local specs = script.Parent:WaitForChild("Specs"):GetChildren()
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)
	for _, spec in ipairs(specs) do
		if spec:IsA("ModuleScript") then
			local ok, err = pcall(function()
				require(spec)(t)
			end)
			if not ok then
				results.failed += 1
				table.insert(results.failures, spec.Name .. " (loading): " .. tostring(err))
			end
		end
	end
	results.summary = string.format("%d passed, %d failed", results.passed, results.failed)
	if #results.failures > 0 then
		results.summary ..= "\n" .. table.concat(results.failures, "\n")
	end
	return results
end

return Runner
