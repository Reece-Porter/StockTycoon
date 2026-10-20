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

return {}
