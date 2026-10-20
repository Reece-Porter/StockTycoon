--!strict
-- Types shared by the server and client.

-- One company a player owns. Saved in their data, and kept exactly as is when
-- it is stolen (valuationMultiplier and hasBeenValued travel with it).
export type CompanyInstance = {
	instanceId: string,
	companyId: string,
	tier: string,
	baseIncome: number,
	-- What the owner paid; selling back returns a share of this.
	purchasePrice: number,
	valuationMultiplier: number,
	hasBeenValued: boolean,
	ownerUserId: number,
}

-- A company in the Valuation Machine. The parameters come from
-- MachinePath.generate; startedAt is workspace:GetServerTimeNow() at the start.
export type MachineRun = {
	company: CompanyInstance,
	seed: number,
	duration: number,
	peak: number,
	peakTime: number,
	startedAt: number,
}

-- One pet a player owns. slotKey (e.g. "Floor2/Slot1") is where it is
-- placed; nil means it is in their pet inventory.
export type PetInstance = {
	instanceId: string,
	petId: string,
	slotKey: string?,
}

return {}
