--!strict
-- Every RemoteEvent the game uses. The server creates them in
-- ReplicatedStorage.Remotes; the client waits for them. Anything a client sends
-- must be rate-limited on the server before it is acted on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local function findOrCreate(parent: Instance, name: string, className: string): Instance
	if not IS_SERVER then
		return parent:WaitForChild(name)
	end

	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local folder = findOrCreate(ReplicatedStorage, "Remotes", "Folder")

local function event(name: string): RemoteEvent
	return findOrCreate(folder, name, "RemoteEvent") :: RemoteEvent
end

return {
	-- Server to client: a short message shown to that player on screen.
	Notify = event("Notify"),

	-- Server to client: (pad: BasePart, amount: number) the player collected
	-- Cash from one of their cash pads.
	Collected = event("Collected"),

	-- Client to server: (itemId: string) buy a company off a conveyor.
	BuyConveyorItem = event("BuyConveyorItem"),

	-- Client to server: (plotKey: string) place the carried company on a plot.
	PlaceOnPlot = event("PlaceOnPlot"),

	-- Client to server: (plotKey: string) pick up the company on a plot.
	PickUpFromPlot = event("PickUpFromPlot"),

	-- Client to server: () put the carried company into storage.
	StoreCarried = event("StoreCarried"),

	-- Client to server: (instanceId: string) take a company out of storage.
	TakeFromStorage = event("TakeFromStorage"),

	-- Client to server: () buy the next base upgrade.
	BuyUpgrade = event("BuyUpgrade"),

	-- Client to server: () put the carried company into the Valuation Machine.
	StartValuation = event("StartValuation"),

	-- Client to server: () lock the current multiplier. Nothing else is sent;
	-- the server works the value out from its own clock.
	TakeValuation = event("TakeValuation"),

	-- Server to client: (multiplier: number, timedOut: boolean) the run ended.
	ValuationFinished = event("ValuationFinished"),

	-- Client to server: (baseName: string, plotKey: string) started holding the
	-- prompt to take someone else's company. The server times the hold.
	StealBegin = event("StealBegin"),

	-- Client to server: (baseName: string, plotKey: string) finished the hold.
	StealFinish = event("StealFinish"),

	-- Client to server: () lock your base from its lock button.
	LockBase = event("LockBase"),

	-- Client to server: (target: Player) the equipped weapon hit this player.
	-- Only a request: the server checks the weapon, cooldown, range and line
	-- of sight before anything happens.
	Attack = event("Attack"),

	-- Client to server: (instanceId: string) pick up a dropped company.
	PickUpDropped = event("PickUpDropped"),

	-- Client to server: (weaponId: string) buy a weapon at the weapon shop.
	BuyWeapon = event("BuyWeapon"),

	-- Client to server: (weaponId: string) hold a weapon you own.
	EquipWeapon = event("EquipWeapon"),

	-- Client to server: () spin for a pet at the pet shop. The server rolls it.
	SpinPet = event("SpinPet"),

	-- Server to client: (petId: string) the pet a spin gave, for the reveal.
	PetSpun = event("PetSpun"),

	-- Client to server: (instanceId: string, slotKey: string) put a pet in a
	-- pet slot on your base.
	PlacePet = event("PlacePet"),

	-- Client to server: (slotKey: string) take the pet in a slot back.
	TakeBackPet = event("TakeBackPet"),

	-- Client to server: (instanceId: string) let a pet go for good.
	DeletePet = event("DeletePet"),

	-- Client to server: () rebirth. The server checks every requirement.
	Rebirth = event("Rebirth"),

	-- Client to server: (minutes: number) claim a playtime reward.
	ClaimPlaytime = event("ClaimPlaytime"),

	-- Client to server: () claim today's daily reward.
	ClaimDaily = event("ClaimDaily"),

	-- Client to server: (count: number) claim an Index prize.
	ClaimIndex = event("ClaimIndex"),

	-- Client to server: (code: string) redeem a code.
	RedeemCode = event("RedeemCode"),

	-- Client to server: () stop showing the new-player guide.
	SkipTutorial = event("SkipTutorial"),

	-- Client to server: (perkId: string) buy the next level of an upgrade at
	-- the upgrade station.
	BuyPerk = event("BuyPerk"),

	-- Client to server: (destination: string) teleport to "Home", "Upgrades"
	-- or "Weapons".
	Travel = event("Travel"),

	-- Client to server: () play your base's Stock Spinner. The server checks
	-- you're at it and it's ready, and rolls the companies itself.
	PlaySpinner = event("PlaySpinner"),

	-- Server to client: (results: string, rolledAt: number, landsAt: number,
	-- luck: number) what your spin rolled, for the pop-up: each company's id
	-- (with ":" and its variant's id for a variant), comma separated, and
	-- when (server time) the reels started and when they stop.
	SpinnerRolled = event("SpinnerRolled"),

	-- Client to server: () join (or, with BattleLeave, leave) the next battle
	-- at the arena's podium.
	BattleJoin = event("BattleJoin"),
	BattleLeave = event("BattleLeave"),

	-- Client to server: () start a practice battle alone, no reward.
	BattlePractice = event("BattlePractice"),

	-- Server to client: (round: number, results: string, rolledAt: number,
	-- landsAt: number, pickBy: number) this round's three stocks for this
	-- player (as SpinnerRolled's results), when the reels stop and when the
	-- pick closes, in server time.
	BattleOffer = event("BattleOffer"),

	-- Client to server: (choice: number) pick one of this round's stocks, 1
	-- to 3.
	BattlePick = event("BattlePick"),

	-- Client to server: (choice: string) "keep" the total or put it through
	-- the "machine".
	BattleChoose = event("BattleChoose"),

	-- Server to client: (run: string) this player's machine run as JSON
	-- (MachinePath params and startedAt), to draw.
	BattleMachine = event("BattleMachine"),

	-- Client to server: () lock the battle machine's multiplier. Nothing else
	-- is sent; the server works it out from its own clock.
	BattleTake = event("BattleTake"),
}
