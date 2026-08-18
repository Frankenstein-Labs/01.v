<script>
import { __, n__, s__, sprintf } from '~/locale';
import ToggleList from './toggle_list.vue';

export default {
  name: 'AttributeScopesList',
  components: { ToggleList },
  i18n: {
    includingLabel: s__('SecurityOrchestration|Including:'),
    excludingLabel: s__('SecurityOrchestration|Excluding:'),
  },
  props: {
    attributeScopes: {
      type: Array,
      required: true,
    },
    compact: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    nonEmptyScopes() {
      return this.attributeScopes.filter(
        (scope) => this.hasIncludingScope(scope) || this.hasExcludingScope(scope),
      );
    },
    includingSummary() {
      const scopes = this.attributeScopes.filter((scope) => this.hasIncludingScope(scope));
      if (scopes.length === 0) return null;
      const total = scopes.reduce((sum, scope) => sum + scope.includingCount, 0);
      return {
        categories: scopes.map((scope) => scope.category.name).join(' · '),
        countLabel: sprintf(n__('%{count} attribute', '%{count} attributes', total), {
          count: total,
        }),
      };
    },
  },
  methods: {
    hasExcludingScope(scope) {
      return scope?.excluding?.length > 0;
    },
    hasIncludingScope(scope) {
      return scope?.including?.length > 0;
    },
    namesOf(attributes) {
      return attributes.map((attr) => attr.name);
    },
    // The list connection loads only the first few attributes, so render a
    // "+ N more" hint for the items that exist server-side but were not loaded.
    moreText(loaded, total) {
      const remaining = Math.max(total - loaded.length, 0);
      if (remaining === 0) return '';
      return sprintf(__('+ %{itemsLength} more'), { itemsLength: remaining });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-5">
    <template v-if="compact">
      <div v-if="includingSummary" data-testid="attribute-scope-including">
        <p class="gl-mb-1">
          <span class="gl-font-bold" data-testid="attribute-scope-categories">{{
            includingSummary.categories
          }}</span>
        </p>
        <p class="gl-mb-0 gl-text-sm gl-text-subtle" data-testid="attribute-scope-count">
          {{ includingSummary.countLabel }}
        </p>
      </div>
    </template>

    <template v-else>
      <div
        v-for="scope in nonEmptyScopes"
        :key="scope.category.key"
        data-testid="attribute-scope-section"
      >
        <h5 class="gl-heading-5 gl-mb-2 gl-mt-0" data-testid="attribute-scope-category">
          {{ scope.category.name }}
        </h5>
        <div
          v-if="hasIncludingScope(scope)"
          class="gl-mb-2"
          data-testid="attribute-scope-including"
        >
          <p class="gl-mb-1 gl-font-bold">{{ $options.i18n.includingLabel }}</p>
          <toggle-list :items="namesOf(scope.including)" bullet-style />
          <p
            v-if="moreText(scope.including, scope.includingCount)"
            class="gl-mb-0 gl-mt-2 gl-text-subtle"
            data-testid="attribute-scope-including-more"
          >
            {{ moreText(scope.including, scope.includingCount) }}
          </p>
        </div>
        <div
          v-if="hasExcludingScope(scope)"
          class="gl-mb-0"
          data-testid="attribute-scope-excluding"
        >
          <p class="gl-mb-1 gl-font-bold">{{ $options.i18n.excludingLabel }}</p>
          <toggle-list :items="namesOf(scope.excluding)" bullet-style />
          <p
            v-if="moreText(scope.excluding, scope.excludingCount)"
            class="gl-mb-0 gl-mt-2 gl-text-subtle"
            data-testid="attribute-scope-excluding-more"
          >
            {{ moreText(scope.excluding, scope.excludingCount) }}
          </p>
        </div>
      </div>
    </template>
  </div>
</template>
