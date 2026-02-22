/* eslint-env node */
module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  parser: "@typescript-eslint/parser",
  parserOptions: {
    // If you want type-aware rules later, uncomment the next line
    // and ensure tsconfig files exist at those paths:
    // project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  settings: {
    // Make `import` plugin resolve TS paths/types correctly
    "import/resolver": {
      typescript: {
        // use <root>/tsconfig.json paths/types; change if needed
        alwaysTryTypes: true,
      },
      node: { extensions: [".js", ".jsx", ".ts", ".tsx"] },
    },
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    // Put Prettier last to disable conflicting stylistic rules from Google/etc.
    "plugin:prettier/recommended",
  ],
  plugins: ["@typescript-eslint", "import"],
  ignorePatterns: [
    "/lib/**/*", // build output
    "/generated/**/*", // generated code
    "/scripts/**/*", // one-off setup scripts
  ],
  rules: {
    // —— Your style choices ——
    quotes: ["error", "double"],
    // indent: ["error", 2],
    indent: ["off"],

    // Cross-platform line endings (avoid CI/Windows pain)
    "linebreak-style": "off",

    // Turn off JS rules that conflict with TS-aware versions
    "no-unused-vars": "off",
    "@typescript-eslint/no-unused-vars": [
      "error",
      { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
    ],
    "no-undef": "off",

    // JSDoc: Google config can nag; TS types usually make this redundant
    "require-jsdoc": "off",
    "valid-jsdoc": "off",

    // Import rules: Firebase/TS often uses path aliases & types-only imports
    "import/no-unresolved": "off", // handled by TS + resolver above
    "import/order": [
      "warn",
      {
        groups: [
          "builtin",
          "external",
          "internal",
          ["parent", "sibling", "index"],
          "type",
          "object",
        ],
        "newlines-between": "always",
        alphabetize: { order: "asc", caseInsensitive: true },
      },
    ],
  },
  overrides: [
    {
      files: ["*.js"],
      rules: {
        // Keep vanilla JS a bit looser if you have admin scripts
        "@typescript-eslint/no-var-requires": "off",
      },
    },
  ],
};
