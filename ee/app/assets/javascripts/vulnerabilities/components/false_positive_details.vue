<script>
import { GlButton, GlIcon, GlProgressBar, GlSprintf, GlTooltipDirective } from '@gitlab/ui';
import NonGfmMarkdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';
import { s__ } from '~/locale';
import { CONFIDENCE_SCORES } from 'ee/vulnerabilities/constants';
import {
  isPendingFpDetection,
  isCompletedFpDetection,
  isFailedFpDetection,
} from 'ee/vulnerabilities/flag_helpers';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_VULNERABILITY } from '~/graphql_shared/constants';
import DismissFalsePositiveModal from 'ee/security_dashboard/components/shared/dismiss_false_positive_modal.vue';

export default {
  name: 'FalsePositiveDetails',
  components: {
    GlButton,
    GlIcon,
    GlProgressBar,
    GlSprintf,
    NonGfmMarkdown,
    DismissFalsePositiveModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    vulnerability: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isDescriptionTruncated: true,
    };
  },
  computed: {
    isLikelyFalsePositive() {
      return (
        this.vulnerability.latestFlag?.confidenceScore >= CONFIDENCE_SCORES.LIKELY_FALSE_POSITIVE
      );
    },
    isAboveFalsePositiveMinimalConfidence() {
      return this.vulnerability.latestFlag?.confidenceScore > CONFIDENCE_SCORES.MINIMAL;
    },
    isPending() {
      return isPendingFpDetection(this.vulnerability.latestFlag);
    },
    isCompleted() {
      return isCompletedFpDetection(this.vulnerability.latestFlag);
    },
    isFailed() {
      return isFailedFpDetection(this.vulnerability.latestFlag);
    },
    canDismissFalsePositive() {
      return this.vulnerability.canAdmin && this.isCompleted;
    },
    falsePositiveResult() {
      if (this.isLikelyFalsePositive) {
        return s__('Vulnerability|likely a false positive');
      }
      if (this.isAboveFalsePositiveMinimalConfidence) {
        return s__('Vulnerability|possibly a false positive');
      }

      return s__('Vulnerability|not a false positive');
    },
    confidencePercentage() {
      return Math.round((this.vulnerability.latestFlag?.confidenceScore ?? 0) * 100);
    },
    confidencePercentageVariant() {
      if (this.isLikelyFalsePositive) {
        return 'success';
      }
      if (this.isAboveFalsePositiveMinimalConfidence) {
        return 'warning';
      }
      return 'primary';
    },
    shouldShowDescription() {
      return this.vulnerability.latestFlag?.description;
    },
    vulnerabilityGraphqlId() {
      return convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerability.id);
    },
    vulnerabilityForModal() {
      return { id: this.vulnerabilityGraphqlId };
    },
  },
  methods: {
    showAllDescription() {
      this.isDescriptionTruncated = false;
    },
    truncateDescription() {
      this.isDescriptionTruncated = true;
    },
    showConfirmModal() {
      this.$refs.confirmModal.show();
    },
    onModalSuccess() {
      window.location.reload();
    },
  },
};
</script>

<template>
  <div data-testid="vulnerability-false-positive-details">
    <template v-if="isPending">
      <p data-testid="false-positive-pending">
        {{
          s__(
            'Vulnerability|AI false positive scan is in progress. Results will appear here when complete.',
          )
        }}
      </p>
    </template>

    <template v-else-if="isFailed">
      <p data-testid="false-positive-failed">
        {{ s__('Vulnerability|AI false positive scan failed. Please try running the scan again.') }}
      </p>
    </template>

    <template v-else>
      <div
        class="gl-my-2 gl-flex gl-items-center gl-gap-3"
        data-testid="false-positive-confidence-score"
      >
        <h3 class="!gl-mb-2">{{ s__('Vulnerability|AI false positive confidence score') }}:</h3>
        <gl-progress-bar
          :value="confidencePercentage"
          class="gl-h-3 gl-w-15"
          :variant="confidencePercentageVariant"
        />
        {{ confidencePercentage }}%
      </div>

      <p data-testid="false-positive-result">
        <gl-sprintf
          :message="
            s__(
              'Vulnerability|GitLab Duo scanned this vulnerability to identify the likelihood that it is a false positive (FP) and found that this vulnerability is %{falsePositiveResult}.',
            )
          "
        >
          <template #falsePositiveResult>
            <strong>{{ falsePositiveResult }}</strong>
          </template>
        </gl-sprintf>
      </p>
    </template>

    <template v-if="shouldShowDescription">
      <h3 class="gl-font-bold">{{ s__('Vulnerability|AI false positive reasoning:') }}</h3>

      <div
        ref="description-content"
        class="gl-relative"
        :class="{ 'gl-max-h-[12vh] gl-overflow-y-hidden': isDescriptionTruncated }"
      >
        <non-gfm-markdown :markdown="vulnerability.latestFlag.description" />
        <div
          v-if="isDescriptionTruncated"
          class="gl-pointer-events-none gl-absolute gl-bottom-0 gl-left-0 gl-right-0 gl-h-12 gl-bg-gradient-to-b gl-from-transparent gl-to-white"
        ></div>
      </div>

      <div v-if="isDescriptionTruncated" class="gl-mt-3 gl-block gl-w-full">
        <gl-button
          variant="link"
          data-testid="show-all-description-btn"
          @click="showAllDescription"
        >
          {{ __('Read more') }}
        </gl-button>
      </div>
      <div v-else class="gl-mt-3 gl-block gl-w-full">
        <gl-button
          variant="link"
          data-testid="show-less-description-btn"
          @click="truncateDescription"
        >
          {{ __('Read less') }}
        </gl-button>
      </div>

      <gl-button
        v-if="canDismissFalsePositive"
        data-testid="remove-false-positive-button"
        class="gl-mt-5"
        category="secondary"
        variant="confirm"
        @click="showConfirmModal"
      >
        {{ s__('Vulnerability|Remove false positive flag') }}
        <gl-icon
          v-gl-tooltip
          name="information-o"
          variant="info"
          :title="s__('Vulnerability|Remove the false positive flag from this vulnerability')"
        />
      </gl-button>
    </template>

    <hr class="gl-border-t-2" />

    <dismiss-false-positive-modal
      ref="confirmModal"
      :vulnerability="vulnerabilityForModal"
      modal-id="dismiss-fp-confirm-modal"
      @success="onModalSuccess"
    />
  </div>
</template>
