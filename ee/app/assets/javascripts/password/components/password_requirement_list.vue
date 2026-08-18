<script>
import { debounce, entries } from 'lodash-es';
import { GlIcon } from '@gitlab/ui';
import * as UsersApi from 'ee/api/users_api';
import { __ } from '~/locale';
import { createAlert } from '~/alert';
import { THOUSAND } from '~/lib/utils/constants';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';

import {
  COMMON,
  USER_INFO,
  INVALID_FORM_CLASS,
  INVALID_INPUT_CLASS,
  PASSWORD_REQUIREMENTS_ID,
  PASSWORD_RULE_MAP,
  RED_TEXT_CLASS,
  GREEN_TEXT_CLASS,
  I18N,
} from '../constants';

export default {
  name: 'PasswordRequirementList',
  components: {
    GlIcon,
  },
  props: {
    allowNoPassword: {
      type: Boolean,
      required: true,
    },
    passwordInputElement: {
      type: Element,
      required: true,
    },
    ruleTypes: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      password: '',
      submitted: false,
      ruleList: this.ruleTypes.map((type) => ({ type, valid: false, ...PASSWORD_RULE_MAP[type] })),
    };
  },
  computed: {
    form() {
      return this.passwordInputElement.form;
    },
    firstName() {
      return this.form.elements.new_user_first_name;
    },
    lastName() {
      return this.form.elements.new_user_last_name;
    },
    username() {
      return this.form.elements.new_user_username;
    },
    email() {
      return this.form.elements.new_user_email;
    },
    anyInvalidRule() {
      return this.ruleList.some((rule) => !rule.valid) && !this.isEmptyPasswordLegal;
    },
    isEmptyPasswordLegal() {
      return this.password.trim() === '' && this.allowNoPassword;
    },
  },
  watch: {
    password() {
      this.ruleList.forEach((rule) => this.checkValidity(rule));
    },
    anyInvalidRule() {
      if (this.anyInvalidRule && this.submitted) {
        this.passwordInputElement.classList.add(INVALID_INPUT_CLASS);
      } else {
        this.passwordInputElement.classList.remove(INVALID_INPUT_CLASS);
      }
    },
  },
  mounted() {
    this.passwordInputElement.setAttribute('aria-describedby', PASSWORD_REQUIREMENTS_ID);
    this.passwordInputElement.addEventListener('input', () => {
      this.password = this.passwordInputElement.value;
    });

    if (this.firstName) {
      this.firstName.addEventListener('input', () => {
        this.checkValidity(this.findRule(USER_INFO));
      });
    }

    if (this.lastName) {
      this.lastName.addEventListener('input', () => {
        this.checkValidity(this.findRule(USER_INFO));
      });
    }

    if (this.username) {
      this.username.addEventListener('input', () => {
        this.checkValidity(this.findRule(USER_INFO));
      });
    }

    if (this.email) {
      this.email.addEventListener('input', () => {
        this.checkValidity(this.findRule(USER_INFO));
      });
    }

    this.form.querySelector('[type="submit"]').addEventListener('click', () => {
      this.submitted = true;
      if (this.anyInvalidRule) {
        this.passwordInputElement.focus();
        this.passwordInputElement.classList.add(INVALID_INPUT_CLASS);
        this.form.classList.add(INVALID_FORM_CLASS);
      }
    });

    this.form.addEventListener('submit', (e) => {
      if (this.anyInvalidRule) {
        e.preventDefault();
        e.stopPropagation();
      }
    });
  },
  methods: {
    validatePasswordComplexity() {
      UsersApi.validatePasswordComplexity(this.passwordComplexityParams())
        .then(({ data }) =>
          entries(data).forEach(([key, value]) => this.setRuleValidity(key, !value)),
        )
        .catch(() =>
          createAlert({
            message: __(
              'Failed to validate password due to server or connection issue. Try again.',
            ),
          }),
        );
    },
    debouncedComplexityValidation: debounce(function complexityValidation() {
      this.validatePasswordComplexity();
    }, THOUSAND),
    checkValidity(rule) {
      if ([COMMON, USER_INFO].includes(rule.type)) {
        this.checkComplexity(rule);
      } else {
        this.setRuleValidity(rule.type, rule.reg.test(this.password));
      }
    },
    checkComplexity(rule) {
      if (this.password) {
        this.debouncedComplexityValidation();
      } else {
        this.setRuleValidity(rule.type, false);
      }
    },
    setRuleValidity(type, valid) {
      const rule = this.findRule(type);

      if (rule) {
        rule.valid = valid;
      }
    },
    findRule(type) {
      return this.ruleList.find((rule) => rule.type === type);
    },
    getAriaLabel(rule) {
      if (rule.valid) {
        return I18N.PASSWORD_SATISFIED;
      }
      if (this.submitted) {
        return I18N.PASSWORD_NOT_SATISFIED;
      }
      return I18N.PASSWORD_TO_BE_SATISFIED;
    },
    calculateTextClass(rule) {
      return {
        [this.$options.RED_TEXT_CLASS]: this.submitted && !rule.valid,
        [this.$options.GREEN_TEXT_CLASS]: rule.valid,
      };
    },
    iconAttrs(rule) {
      if (this.submitted && !rule.valid) {
        return { name: 'close', size: 16 };
      }

      if (rule.valid) {
        return { name: 'check', size: 16 };
      }

      return { name: 'status_created_borderless', size: 12 };
    },
    ruleText(rule) {
      return capitalizeFirstCharacter(rule.text);
    },
    passwordComplexityParams() {
      return {
        ...(this.firstName && { first_name: this.firstName.value }),
        ...(this.lastName && { last_name: this.lastName.value }),
        ...(this.username && { username: this.username.value }),
        ...(this.email && { email: this.email.value }),
        password: this.password,
      };
    },
  },
  RED_TEXT_CLASS,
  GREEN_TEXT_CLASS,
};
</script>

<template>
  <div
    v-show="!isEmptyPasswordLegal"
    class="gl-text-subtle"
    data-testid="password-requirement-list"
  >
    <div
      v-for="(rule, index) in ruleList"
      :key="rule.text"
      class="gl-mb-3 gl-flex"
      aria-live="polite"
    >
      <span
        :data-testid="`password-${ruleTypes[index]}-status-icon`"
        class="gl-mr-2 gl-flex gl-w-5 gl-items-center gl-justify-center"
        :aria-label="getAriaLabel(rule)"
      >
        <gl-icon :class="calculateTextClass(rule)" v-bind="iconAttrs(rule)" />
      </span>
      <span data-testid="password-rule-text" :class="calculateTextClass(rule)">
        {{ ruleText(rule) }}
      </span>
    </div>
  </div>
</template>
