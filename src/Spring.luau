--!strict

-- Analytic underdamped spring stepper.
--
-- `Step` is the closed-form solution of a damped harmonic oscillator, so it stays stable at ANY frame delta --
-- callers drive it from a Heartbeat/RenderStepped loop and it never diverges on a long frame, the way a naive
-- Euler integrator would. Pure math: no Roblox instances, no per-call allocation, no state of its own. The
-- caller owns the `(position, velocity)` pair and feeds it back in each frame.
--
-- BlockText steps four of these per cube (x, y, z and scale), which is why this is allocation-free.
--
--   local pos, vel = 0, 0
--   pos, vel = Spring.Step(pos, vel, target, deltaTime, 16, 0.7)

local Spring = {}

-- Damping ratio < 1 is what produces the overshoot-and-settle bounce; the angular frequency sets how fast the
-- value converges. Clamped just below 1 in `Step` so the sqrt below never goes imaginary.
local MAX_DAMPING_RATIO = 0.999

-- Advances `(position, velocity)` one `deltaTime` toward `target`. Returns the new pair; mutates nothing.
function Spring.Step(
	position: number,
	velocity: number,
	target: number,
	deltaTime: number,
	angularFrequency: number,
	dampingRatio: number
): (number, number)
	local omega = angularFrequency
	local zeta = math.min(dampingRatio, MAX_DAMPING_RATIO)
	local damped = omega * math.sqrt(1 - zeta * zeta)

	local offset = position - target
	local decay = math.exp(-zeta * omega * deltaTime)
	local cosine = math.cos(damped * deltaTime)
	local sine = math.sin(damped * deltaTime)

	local a = offset
	local b = (velocity + zeta * omega * offset) / damped

	local newPosition = target + decay * (a * cosine + b * sine)
	local newVelocity = decay * ((-zeta * omega * a + b * damped) * cosine + (-zeta * omega * b - a * damped) * sine)
	return newPosition, newVelocity
end

return Spring
