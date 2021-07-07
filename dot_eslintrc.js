'use strict';

//minimal config
module.exports = {
  extends: ['eslint:recommended', 'plugin:prettier/recommended'],
  env: {
    browser: true,
    es6: true,
  },
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
