--!strict
-- Steps that upgrade old saves. Migrations[n] turns a version n save into a
-- version n + 1 save by editing the table in place. DataService runs every step
-- a save needs, in order, before filling in new fields from Template.
--
-- Example, if version 2 renamed Cash to Money:
--
--     [1] = function(data)
--         data.Money = data.Cash
--         data.Cash = nil
--     end,

return {} :: { [number]: (data: { [string]: any }) -> () }
