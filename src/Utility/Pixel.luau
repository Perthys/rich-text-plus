--!strict
--!native
--!optimize 2

const Limit: number = 4096
const Span: number = 2 ^ 20
const Reach: number = 2 ^ 19

const Cache: { [number]: UDim2 } = {}

local Count: number = 0

const function Truncate(Value: number): number
	return if Value >= 0 then math.floor(Value) else math.ceil(Value)
end

const function Offset(X: number, Y: number): UDim2
	if X >= Span or X <= -Span or Y >= Reach or Y <= -Reach then return UDim2.fromOffset(X, Y) end

	const Key: number = X * Span + Y
	const Known: UDim2? = Cache[Key]
	if Known then return Known :: UDim2 end

	if Count >= Limit then
		table.clear(Cache)
		Count = 0
	end

	const Created: UDim2 = UDim2.fromOffset(X, Y)
	Cache[Key] = Created
	Count += 1

	return Created
end

return {
	Truncate = Truncate;
	Offset = Offset;
}
