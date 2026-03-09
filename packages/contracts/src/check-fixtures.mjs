import fs from "node:fs";
import path from "node:path";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const root = path.resolve(import.meta.dirname, "..");
const schemaDir = path.join(root, "schemas");
const fixtureDir = path.join(root, "fixtures");

const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);

const loadJson = (filePath) => JSON.parse(fs.readFileSync(filePath, "utf8"));

const schemaFiles = fs.readdirSync(schemaDir).filter((file) => file.endsWith(".json"));
for (const schemaFile of schemaFiles) {
  ajv.addSchema(loadJson(path.join(schemaDir, schemaFile)), schemaFile);
}

const pairs = [
  ["context-signal.v1.schema.json", "context-signal.wake.json"],
  ["context-event.v1.schema.json", "context-event.driving_started.json"],
  ["context-snapshot.v1.schema.json", "context-snapshot.default.json"],
  ["policy-decision.v1.schema.json", "policy-decision.driving_started.json"],
  ["sensekit-event-envelope.v1.schema.json", "sensekit-event-envelope.driving_started.json"]
];

let failed = false;

for (const [schemaFile, fixtureFile] of pairs) {
  const validate = ajv.getSchema(schemaFile);
  if (!validate) {
    console.error(`Missing schema: ${schemaFile}`);
    failed = true;
    continue;
  }

  const fixture = loadJson(path.join(fixtureDir, fixtureFile));
  const valid = validate(fixture);
  if (!valid) {
    failed = true;
    console.error(`Fixture validation failed for ${fixtureFile}`);
    console.error(validate.errors);
  }
}

if (failed) {
  process.exit(1);
}

console.log("All SenseKit contract fixtures are valid.");
