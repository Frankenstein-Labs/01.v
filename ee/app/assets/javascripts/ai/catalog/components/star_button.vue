<script>
import { GlButton, GlTooltipDirective, GlToastMixin } from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import aiCatalogItemStarMutation from '../graphql/mutations/ai_catalog_item_star.mutation.graphql';

export default {
  name: 'StarButton',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [GlToastMixin],
  props: {
    item: {
      type: Object,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isLoading: false,
      count: this.item.starCount,
      isStarred: this.item.starred,
    };
  },
  computed: {
    starIcon() {
      return this.isStarred ? 'star' : 'star-o';
    },
    starLabel() {
      return this.isStarred ? s__('AICatalog|Unstar') : s__('AICatalog|Star');
    },
    isButtonDisabled() {
      return this.disabled || this.isLoading;
    },
    tooltip() {
      if (this.disabled) {
        return s__('AICatalog|You must sign in to star this item');
      }
      return '';
    },
  },
  methods: {
    showErrorToast() {
      this.$toast.show(s__('AICatalog|Star toggle failed. Try again later.'), {
        variant: 'danger',
      });
    },
    async toggleStar() {
      if (this.disabled) {
        return;
      }

      try {
        this.isLoading = true;
        const { data } = await this.$apollo.mutate({
          mutation: aiCatalogItemStarMutation,
          variables: {
            input: {
              id: this.item.id,
              starred: !this.isStarred,
            },
          },
        });

        const result = data.aiCatalogItemStar;
        if (result.errors && result.errors.length > 0) {
          Sentry.captureException(new Error(result.errors.join(', ')));
          this.showErrorToast();
        } else {
          this.count = result.starCount;
          this.isStarred = !this.isStarred;
        }
      } catch (error) {
        Sentry.captureException(error);
        this.showErrorToast();
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>

<template>
  <span v-gl-tooltip :title="tooltip" class="gl-inline-block" data-testid="star-button-wrapper">
    <gl-button
      :icon="starIcon"
      :count="count"
      :loading="isLoading"
      :disabled="isButtonDisabled"
      variant="default"
      data-testid="star-button"
      @click="toggleStar"
      >{{ starLabel }}</gl-button
    >
  </span>
</template>
