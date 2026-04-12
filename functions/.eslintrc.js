module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: ["eslint:recommended"],
  parserOptions: {
    ecmaVersion: 2020,
  },
  rules: {
    "linebreak-style": "off",
    "object-curly-spacing": "off",
    "no-unused-vars": "off",
  },
};