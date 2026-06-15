module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],
    "valid-jsdoc": "off", // ✅ JSDoc 강제 끄기
    "max-len": ["warn", {code: 120, ignoreUrls: true}], // ✅ 줄 길이 120자로 완화
    "object-curly-spacing": "off",
    "comma-spacing": "off",
    "require-jsdoc": "off",
    "@typescript-eslint/no-explicit-any": "off",
    "brace-style": "off",
  },
};
