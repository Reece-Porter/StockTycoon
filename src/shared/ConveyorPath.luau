--!strict
-- Where a company on a conveyor is at a given moment. The server uses this to
-- check buying distance and the client uses it to draw the movement, so both
-- agree. Times come from workspace:GetServerTimeNow(), which is the same on
-- the server and every client.

local ConveyorPath = {}

-- 0 at the Start, 1 at the End.
function ConveyorPath.progress(spawnedAt: number, travelSeconds: number, now: number): number
	return math.clamp((now - spawnedAt) / travelSeconds, 0, 1)
end

function ConveyorPath.cframeAt(
	startCFrame: CFrame,
	endCFrame: CFrame,
	spawnedAt: number,
	travelSeconds: number,
	now: number
): CFrame
	return startCFrame:Lerp(endCFrame, ConveyorPath.progress(spawnedAt, travelSeconds, now))
end

return ConveyorPath
