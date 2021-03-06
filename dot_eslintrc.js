'use strict';

//minimal config
module.exports = {
  root: true,
  extends: ['eslint:recommended'],
  env: {
    browser: true,
    es6: true,
    node: true,
  },
  parserOptions: { ecmaVersion: 2021 },
  rules: {
    'arrow-body-style': ['error', 'as-needed'],
    'consistent-this': ['error', 'void'],
    'no-else-return': 'error',
    'no-var': 'error',
    'prefer-const': 'error',
    'prefer-arrow-callback': [
      'error',
      {
        allowNamedFunctions: false,
        allowUnboundThis: true,
      },
    ],
  },
};
