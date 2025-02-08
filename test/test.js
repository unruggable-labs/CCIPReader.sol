import { Foundry } from "@adraffy/blocksmith";
import { serve } from "@resolverworks/ezccip/serve";
import { EZCCIP } from "@resolverworks/ezccip";
import { test } from "node:test";
import assert from "node:assert/strict";

test("CCIPReader", async (T) => {
	const foundry = await Foundry.launch({ infoLog: false });
	T.after(foundry.shutdown);

	// https://en.wikipedia.org/wiki/Collatz_conjecture
	const collatz = (x) => (x & 1n ? 3n * x + 1n : x >> 1n);
	const collatzSeq = (x) => {
		const v = [x];
		while (x !== 1n) v.push((x = collatz(x)));
		return v;
	};
	await T.test("collatz", () =>
		assert.deepEqual(collatzSeq(3n), [3n, 10n, 5n, 16n, 8n, 4n, 2n, 1n])
	);

	// offchain server
	const ezccip = new EZCCIP();
	ezccip.register("next(uint256) returns (uint256)", ([x]) => [collatz(x)]);
	const ccip = await serve(ezccip, { log: true, protocol: "raw" });
	T.after(ccip.shutdown);

	// ccip-read contract that calls offchain server
	const Offchain = await foundry.deploy({
		file: "Offchain",
		args: [[ccip.endpoint]],
	});

	// ccip-read contract that calls another ccip-read contract
	const Wrapper = await foundry.deploy({
		file: "Wrapper",
	});

	await T.test("direct w/offchain: get(2)", async (TT) => {
		const arg = extractArg(TT.name);
		assert.equal(
			await Offchain.get(arg, { enableCcipRead: true }),
			collatz(arg)
		);
	});

	await T.test(`recursive w/offchain: list(3)`, async (TT) => {
		const arg = extractArg(TT.name);
		assert.deepEqual(
			(await Offchain.list(arg, { enableCcipRead: true })).toArray(),
			collatzSeq(arg)
		);
	});

	const CARRY = "0xdeadbeef"; // our own context variable

	await T.test("wrapped direct w/offchain: get(2)", async (TT) => {
		const arg = extractArg(TT.name);
		const [offchain, carry] = await Wrapper.wrap(
			Offchain,
			Offchain.interface.encodeFunctionData("get", [arg]),
			CARRY,
			{ enableCcipRead: true }
		);
		assert.equal(carry, CARRY);
		const [next] = Offchain.interface.decodeFunctionResult("get", offchain);
		assert.deepEqual(next, collatz(arg));
	});

	await T.test(`wrapped recursive w/offchain: list(3)`, async (TT) => {
		const arg = extractArg(TT.name);
		const [offchain, carry] = await Wrapper.wrap(
			Offchain,
			Offchain.interface.encodeFunctionData("list", [arg]),
			CARRY,
			{ enableCcipRead: true }
		);
		assert.equal(carry, CARRY);
		const [seq] = Offchain.interface.decodeFunctionResult("list", offchain);
		assert.deepEqual(seq.toArray(), collatzSeq(arg));
	});

	await T.test(`wrapped direct w/o offchain: list(1)`, async (TT) => {
		const arg = extractArg(TT.name);
		const [offchain, carry] = await Wrapper.wrap(
			Offchain,
			Offchain.interface.encodeFunctionData("list", [arg]),
			CARRY
			//{ enableCcipRead: true }
		);
		assert.equal(carry, CARRY);
		const [seq] = Offchain.interface.decodeFunctionResult("list", offchain);
		assert.deepEqual(seq.toArray(), collatzSeq(arg));
	});
});

function extractArg(name) {
	return BigInt(name.match(/\((\d+)\)/)[1]);
}
