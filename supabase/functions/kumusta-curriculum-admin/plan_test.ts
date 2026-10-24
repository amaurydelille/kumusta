import { assignment, goals, syllabus } from "./plan.ts";

Deno.test("curriculum covers all 160 outcomes without overlapping keys", () => {
  const keys = new Set<string>();
  for (const goal of goals) {
    if (syllabus[goal].length !== 4) throw new Error("missing stage");
    for (let stage = 1; stage <= 4; stage++) {
      const outcomes = syllabus[goal][stage - 1];
      if (outcomes.length !== 10 || new Set(outcomes).size !== 10) {
        throw new Error("missing or duplicate outcome");
      }
      for (let order = 1; order <= 10; order++) {
        const brief = assignment(goal, stage, order);
        const key = brief.required_scenario_key;
        if (keys.has(key)) throw new Error("duplicate key");
        keys.add(key);
        if (!/^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(key)) throw new Error(`invalid key: ${key}`);
        if (brief.outcome.length > 72) throw new Error(`UI scenario too long: ${brief.outcome}`);
        if (brief.difficulty < 1 || brief.difficulty > 5) throw new Error("invalid difficulty");
        if (brief.prior_outcomes.length !== order - 1) throw new Error("incorrect continuity");
      }
    }
  }
  if (keys.size !== 160) throw new Error("incomplete curriculum coverage");
});
