<script>
import { GlAccordion, GlAccordionItem, GlAlert, GlSprintf, GlTruncate } from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { s__, sprintf } from '~/locale';

const DEFAULT_SBOM_ERROR_DESCRIPTION = s__(
  'SbomErrors|The following SBOM reports could not be parsed. Therefore the list of components may be incomplete.',
);

export default {
  name: 'SbomReportsErrorsAlert',
  components: {
    GlAlert,
    GlSprintf,
    GlAccordion,
    GlAccordionItem,
    GlTruncate,
    HelpPageLink,
  },
  props: {
    errors: {
      type: Array,
      required: true,
    },
    errorDescription: {
      type: String,
      required: false,
      default: DEFAULT_SBOM_ERROR_DESCRIPTION,
    },
  },
  computed: {
    errorsWithTitles() {
      return this.errors.map((reportErrors, index) => ({
        reportErrors,
        parsedErrors: reportErrors.map((error) => ({
          message: error?.message ?? String(error),
          helpLink: error?.help_link ?? null,
        })),
        accordionTitle: sprintf(this.$options.i18n.ACCORDION_TITLE, {
          index: index + 1,
          length: reportErrors.length,
        }),
      }));
    },
  },
  i18n: {
    SBOM_ERROR_ALERT_TITLE: s__('SbomErrors|Error parsing SBOM reports'),
    DEFAULT_SBOM_ERROR_DESCRIPTION,
    SBOM_ERROR_ACTION: s__(
      'SbomErrors|Please investigate the provided reports and ensure they conform to %{helpPageLinkStart}the requirements for SBOM documents%{helpPageLinkEnd}.',
    ),
    ACCORDION_TITLE: s__('SbomErrors|report-%{index} (%{length})'),
    LEARN_MORE: s__('SbomErrors|Learn more'),
  },
};
</script>

<template>
  <gl-alert variant="danger" :dismissible="false">
    <strong role="heading">
      {{ $options.i18n.SBOM_ERROR_ALERT_TITLE }}
    </strong>

    <p class="gl-mt-3" data-testid="sbom-error-description">
      <gl-sprintf :message="errorDescription" />
    </p>
    <p>
      <gl-sprintf :message="$options.i18n.SBOM_ERROR_ACTION">
        <template #helpPageLink="{ content }">
          <help-page-link
            href="user/application_security/dependency_list/_index"
            anchor="set-up-the-dependency-list"
            target="_blank"
          >
            {{ content }}
          </help-page-link>
        </template>
      </gl-sprintf>
    </p>

    <gl-accordion :header-level="3">
      <gl-accordion-item
        v-for="({ parsedErrors, accordionTitle }, index) in errorsWithTitles"
        :key="index"
        :title="accordionTitle"
      >
        <ul class="gl-pl-4">
          <li
            v-for="(parsedError, errorIndex) in parsedErrors"
            :key="`${index}-${errorIndex}`"
            class="gl-flex gl-items-center gl-gap-2"
          >
            <gl-truncate :text="parsedError.message" with-tooltip />
            <!-- eslint-disable-next-line local-rules/vue-require-valid-help-page-link-component -->
            <help-page-link
              v-if="parsedError.helpLink"
              :href="parsedError.helpLink"
              target="_blank"
              class="gl-shrink-0"
            >
              {{ $options.i18n.LEARN_MORE }}
            </help-page-link>
          </li>
        </ul>
      </gl-accordion-item>
    </gl-accordion>
  </gl-alert>
</template>
