--!strict
-- Simple shapes for models built from config: companies (Config/CompanyLooks),
-- pets (Config/PetLooks) and weapons (Config/WeaponLooks). A look is a list of
-- pieces made with the helpers here; make() turns one into a part.
--
-- Positions are in studs from the model's base point: x to the right, y up,
-- and the front is -z. turn is in degrees about x, then y, then z. Cylinders
-- lie along x; can() stands one up and disc() turns one to face the front.

export type Vec = { number }

export type Text = {
	text: string,
	-- "Front" or "Top", of the piece before it is turned.
	face: string,
	colour: Color3,
}

export type Piece = {
	-- "Block", "Ball", "Cylinder", "Wedge" or "Ellipsoid".
	shape: string,
	size: Vec,
	at: Vec,
	turn: Vec?,
	-- The way a cylinder points before it is turned: "x", "y" (standing up)
	-- or "z" (facing the front).
	axis: string?,
	colour: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	text: Text?,
}

export type Options = {
	turn: Vec?,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	text: Text?,
}

local Pieces = {}

-- Pieces smaller than this (their longest side) cast no shadow.
Pieces.SmallPiece = 1.2

-- Stands a cylinder (which lies along x) up.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- How a cylinder is turned before its own turn, by the way it points.
local AXES: { [string]: CFrame } = {
	x = CFrame.new(),
	y = UPRIGHT,
	z = CFrame.Angles(0, math.rad(90), 0),
}

-- Which of the part's own faces ends up at the front or on top, by the way
-- a cylinder points.
Pieces.Faces = {
	x = { Front = Enum.NormalId.Front, Top = Enum.NormalId.Top },
	y = { Front = Enum.NormalId.Front, Top = Enum.NormalId.Right },
	z = { Front = Enum.NormalId.Right, Top = Enum.NormalId.Top },
} :: { [string]: { [string]: Enum.NormalId } }

local SHAPES: { [string]: Enum.PartType } = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
	Wedge = Enum.PartType.Wedge,
	-- A block with a sphere mesh, which stretches with the part.
	Ellipsoid = Enum.PartType.Block,
}

function Pieces.piece(shape: string, size: Vec, at: Vec, colour: Color3, options: Options?, axis: string?): Piece
	local extra: Options = options or {}
	return {
		shape = shape,
		size = size,
		at = at,
		turn = extra.turn,
		axis = axis,
		colour = colour,
		material = extra.material,
		transparency = extra.transparency,
		reflectance = extra.reflectance,
		text = extra.text,
	}
end

function Pieces.block(size: Vec, at: Vec, colour: Color3, options: Options?): Piece
	return Pieces.piece("Block", size, at, colour, options)
end

function Pieces.ball(diameter: number, at: Vec, colour: Color3, options: Options?): Piece
	return Pieces.piece("Ball", { diameter, diameter, diameter }, at, colour, options)
end

-- A stretched ball.
function Pieces.ellipsoid(size: Vec, at: Vec, colour: Color3, options: Options?): Piece
	return Pieces.piece("Ellipsoid", size, at, colour, options)
end

-- A ramp: full height at the back (+z), sloping down to the front.
function Pieces.wedge(size: Vec, at: Vec, colour: Color3, options: Options?): Piece
	return Pieces.piece("Wedge", size, at, colour, options)
end

-- A cylinder lying along x (before any turn).
function Pieces.rod(length: number, diameter: number, at: Vec, colour: Color3, options: Options?): Piece
	return Pieces.piece("Cylinder", { length, diameter, diameter }, at, colour, options, "x")
end

-- A cylinder standing up.
function Pieces.can(height: number, diameter: number, at: Vec, colour: Color3, options: Options?): Piece
	return Pieces.piece("Cylinder", { height, diameter, diameter }, at, colour, options, "y")
end

-- A cylinder facing the front, like a coin held up.
function Pieces.disc(thickness: number, diameter: number, at: Vec, colour: Color3, options: Options?): Piece
	return Pieces.piece("Cylinder", { thickness, diameter, diameter }, at, colour, options, "z")
end

function Pieces.vector(values: { number }): Vector3
	return Vector3.new(values[1] or 0, values[2] or 0, values[3] or 0)
end

function Pieces.angles(degrees: { number }?): CFrame
	if degrees == nil then
		return CFrame.new()
	end
	return CFrame.Angles(math.rad(degrees[1] or 0), math.rad(degrees[2] or 0), math.rad(degrees[3] or 0))
end

-- A part only for looks: anchored, and nothing collides with it, touches it
-- or hits it with a raycast. Small ones cast no shadow.
function Pieces.newPart(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	colour: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	-- Shape first: a Ball keeps its sides equal.
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = math.max(size.X, size.Y, size.Z) >= Pieces.SmallPiece
	part.Parent = parent
	return part
end

-- The piece as a part in parent, placed from base. Returns the part and
-- where it went.
function Pieces.make(parent: Instance, name: string, piece: Piece, base: CFrame): (Part, CFrame)
	local shape: Enum.PartType? = SHAPES[piece.shape]
	local axis = piece.axis or "x"
	local turned: CFrame? = AXES[axis]
	if shape == nil or turned == nil then
		error(`[Pieces] {name}: unknown shape {piece.shape} or axis {axis}`)
	end
	local size = Pieces.vector(piece.size)
	local cframe = base * CFrame.new(Pieces.vector(piece.at)) * Pieces.angles(piece.turn) * turned
	local part = Pieces.newPart(parent, name, shape, size, cframe, piece.colour)
	if piece.shape == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Material = piece.material or Enum.Material.SmoothPlastic
	part.Transparency = piece.transparency or 0
	part.Reflectance = piece.reflectance or 0
	if part.Transparency > 0 or part.Material == Enum.Material.Neon then
		part.CastShadow = false
	end
	return part, cframe
end

-- How high a part reaches above its centre, however it's turned.
function Pieces.reach(cframe: CFrame, size: Vector3): number
	return math.abs(cframe.RightVector.Y) * size.X / 2
		+ math.abs(cframe.UpVector.Y) * size.Y / 2
		+ math.abs(cframe.LookVector.Y) * size.Z / 2
end

return Pieces
