<script>
import {
  GlBadge,
  GlLink,
  GlModal,
  GlModalDirective,
  GlFriendlyWrap,
  GlTooltipDirective,
  GlIntersperse,
} from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { sprintf, s__, n__ } from '~/locale';

// If there are more licenses than this count, a counter will be displayed for the remaining licenses
// e.g.: VISIBLE_LICENSES_COUNT = 1; licenses = ['MIT', 'GNU', 'GPL'] -> 'MIT and +2 more'
const VISIBLE_LICENSES_COUNT = 1;
const MODAL_ID_PREFIX = 'dependency-license-link-modal-';

// Constants for unknown license handling
const UNKNOWN_SPDX_IDENTIFIER = 'unknown';
const UNKNOWN_LICENSE_NAME = 'unknown';
const SINGLE_UNKNOWN_LICENSE_NAME = '1 unknown';

export default {
  name: 'DependencyLicenseLinks',
  components: {
    GlBadge,
    GlLink,
    GlModal,
    GlFriendlyWrap,
    GlIntersperse,
  },
  directives: {
    GlModalDirective,
    GlTooltipDirective,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    licenses: {
      type: Array,
      required: true,
    },
  },
  computed: {
    allLicenses() {
      if (!Array.isArray(this.licenses)) return [];

      const knownLicenses = this.licenses
        .filter((license) => license.spdxIdentifier !== UNKNOWN_SPDX_IDENTIFIER)
        .sort((a, b) => a.name.localeCompare(b.name));

      return this.unknownLicense ? [...knownLicenses, this.unknownLicense] : knownLicenses;
    },
    hasPolicyViolations() {
      return this.allLicenses.some((lic) => Boolean(lic?.policyViolations?.length));
    },
    unknownLicense() {
      if (!Array.isArray(this.licenses)) return null;

      return this.licenses.find((license) => license.spdxIdentifier === UNKNOWN_SPDX_IDENTIFIER);
    },
    unknownCount() {
      if (!this.unknownLicense) return 0;

      // If a license has an 'unknown' SPDX identifier, its name field is formatted as '<count> unknown'.
      // For more details, refer to: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/179373
      return Number(this.unknownLicense.name?.split(' ')[0]) || 1;
    },
    visibleLicenses() {
      return this.allLicenses.slice(0, VISIBLE_LICENSES_COUNT);
    },
    remainingLicensesCount() {
      let hiddenLicensesCount = this.allLicenses.length - VISIBLE_LICENSES_COUNT;

      if (this.unknownCount) {
        hiddenLicensesCount += this.unknownCount - 1;
      }

      return hiddenLicensesCount < 0 ? 0 : hiddenLicensesCount;
    },
    hasLicensesInModal() {
      return this.remainingLicensesCount > 0;
    },
    modalId() {
      return uniqueId(MODAL_ID_PREFIX);
    },
    modalActionText() {
      return s__('Modal|Close');
    },
    modalBadgeText() {
      return sprintf(s__('Dependencies|+%{remainingLicensesCount} more'), {
        remainingLicensesCount: this.remainingLicensesCount,
      });
    },
    unidentifiedLicensesText() {
      if (this.unknownCount === 0) return null;
      return sprintf(
        n__(
          'Licenses|This package also includes a license which was not identified by the scanner.',
          'Licenses|This package also includes %{count} licenses which were not identified by the scanner.',
          this.unknownCount,
        ),
        { count: this.unknownCount },
      );
    },
    lastSeparator() {
      return ` ${s__('SeriesFinalConjunction|and')} `;
    },
  },
  methods: {
    formattedLicenseName(license) {
      return license.spdxIdentifier === UNKNOWN_SPDX_IDENTIFIER &&
        license.name === SINGLE_UNKNOWN_LICENSE_NAME
        ? UNKNOWN_LICENSE_NAME
        : license.name;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-justify-self-end @md/panel:gl-justify-self-start">
    <gl-intersperse :last-separator="lastSeparator" data-testid="license-list">
      <span
        v-for="license in visibleLicenses"
        :key="license.spdxIdentifier"
        data-testid="license-list-item"
      >
        <gl-link v-if="license.url" :href="license.url" target="_blank">
          {{ formattedLicenseName(license) }}
        </gl-link>
        <gl-friendly-wrap v-else :text="formattedLicenseName(license)" />
      </span>
    </gl-intersperse>
    <gl-badge
      v-if="hasLicensesInModal"
      v-gl-modal-directive="modalId"
      v-gl-tooltip-directive.bottom="unidentifiedLicensesText"
      :title="unidentifiedLicensesText"
      href="#"
      variant="neutral"
      class="gl-ml-3 !gl-align-baseline"
      data-testid="license-badge"
    >
      {{ modalBadgeText }}
    </gl-badge>
    <gl-badge
      v-if="hasPolicyViolations"
      class="gl-ml-3"
      data-testid="policy-violation-badge"
      icon="cancel"
      variant="warning"
    >
      {{ s__('Dependencies|Policy violation') }}
    </gl-badge>
    <div data-testid="modal">
      <gl-modal
        v-if="hasLicensesInModal"
        :title="title"
        :modal-id="modalId"
        :ok-title="modalActionText"
        ok-only
        ok-variant="secondary"
      >
        <h5>{{ __('Licenses') }}</h5>
        <ul class="list-unstyled">
          <li v-for="license in allLicenses" :key="license.spdxIdentifier" data-testid="modal-item">
            <gl-link v-if="license.url" :href="license.url" target="_blank">
              {{ formattedLicenseName(license) }}
            </gl-link>
            <span v-else>{{ formattedLicenseName(license) }}</span>
          </li>
        </ul>
      </gl-modal>
    </div>
  </div>
</template>
