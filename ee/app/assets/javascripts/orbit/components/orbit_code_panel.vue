<script>
import { GlBadge, GlButton, GlIcon, GlLoadingIcon, GlTooltipDirective } from '@gitlab/ui';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { s__, __, sprintf } from '~/locale';
import OrbitCodeIntelligenceMixin from '../mixins/orbit_code_intelligence_mixin';

export default {
  name: 'OrbitCodePanel',
  components: { CrudComponent, GlBadge, GlButton, GlIcon, GlLoadingIcon },
  directives: { GlTooltip: GlTooltipDirective },
  mixins: [OrbitCodeIntelligenceMixin],
  emits: ['close'],
  computed: {
    searchActionTitle() {
      if (!this.selectedDef) return '';
      return sprintf(this.$options.i18n.searchProjectWide, { name: this.selectedDef.name });
    },
  },
  i18n: {
    title: s__('Orbit|Code Navigation'),
    intro: s__(
      'Orbit|Find definitions and references for functions and other symbols in this file. Click a symbol to see where it is defined and called.',
    ),
    noSymbols: s__('Orbit|No indexed symbols in this file.'),
    noReferences: s__('Orbit|No references found.'),
    noCalls: s__('Orbit|No outbound calls found.'),
    callers: s__('Orbit|callers'),
    references: s__('Orbit|References'),
    calls: s__('Orbit|Calls'),
    jumpToDefinition: s__('Orbit|Jump to definition'),
    searchProjectWide: s__('Orbit|Search this project for %{name}'),
    backLabel: s__('Orbit|Back to symbols'),
    closeLabel: s__('Orbit|Close code navigation panel'),
    leaveFeedback: __('Leave Feedback'),
    feedbackUrl: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/599149',
  },
};
</script>

<template>
  <crud-component
    :title="$options.i18n.title"
    :count="definitions.length"
    :is-loading="loading"
    :is-collapsible="true"
    title-tag="h3"
    class="!gl-mt-0"
  >
    <template #actions>
      <gl-button
        category="tertiary"
        size="small"
        icon="close"
        :aria-label="$options.i18n.closeLabel"
        @click="$emit('close')"
      />
    </template>

    <!-- Symbol list view -->
    <template v-if="!selectedDef">
      <p data-testid="panel-intro" class="gl-mb-3 gl-mt-0 gl-text-sm gl-text-subtle">
        {{ $options.i18n.intro }}
      </p>
      <p
        v-if="!definitions.length"
        data-testid="no-symbols"
        class="gl-m-0 gl-text-sm gl-text-subtle"
      >
        {{ $options.i18n.noSymbols }}
      </p>
      <ul
        v-else
        data-testid="symbol-list"
        class="gl-m-0 gl-flex gl-list-none gl-flex-col gl-gap-1 gl-p-0"
      >
        <li
          v-for="{ def, depth } in definitionsTree"
          :key="def.id"
          data-testid="symbol-item"
          :style="depth ? { paddingLeft: `${depth * 12}px` } : null"
          class="gl-flex gl-cursor-pointer gl-items-center gl-gap-2 gl-rounded-base gl-px-2 gl-py-1 hover:gl-bg-subtle"
          @click="selectDef(def)"
        >
          <gl-icon
            :name="typeIcon(def.definition_type)"
            :size="14"
            :variant="typeVariant(def.definition_type)"
            :title="def.definition_type"
            class="gl-shrink-0"
          />
          <span class="gl-font-mono gl-truncate gl-text-sm" :title="def.fqn">{{ def.name }}</span>
          <gl-badge
            v-if="callersFor(def.id)"
            size="sm"
            variant="neutral"
            class="gl-ml-auto gl-shrink-0"
          >
            {{ callersFor(def.id) }} {{ $options.i18n.callers }}
          </gl-badge>
        </li>
      </ul>
    </template>

    <!-- Definition detail view -->
    <template v-else>
      <gl-button
        data-testid="back-button"
        category="tertiary"
        size="small"
        icon="go-back"
        class="-gl-ml-2 gl-mb-3"
        :aria-label="$options.i18n.backLabel"
        @click="clearSelection"
        >{{ $options.i18n.backLabel }}</gl-button
      >

      <div data-testid="symbol-detail" class="gl-flex gl-flex-col gl-gap-3">
        <!-- Selected symbol name + FQN -->
        <div class="gl-flex gl-items-start gl-gap-2">
          <gl-icon
            :name="typeIcon(selectedDef.definition_type)"
            :size="14"
            :variant="typeVariant(selectedDef.definition_type)"
            :title="selectedDef.definition_type"
            class="gl-mt-1 gl-shrink-0"
          />
          <div class="gl-flex gl-min-w-0 gl-flex-col">
            <span
              class="gl-font-mono gl-truncate gl-text-sm gl-font-semibold gl-text-default"
              :title="selectedDef.name"
            >
              {{ selectedDef.name }}
            </span>
            <span
              class="gl-font-mono gl-truncate gl-text-xs gl-text-subtle"
              :title="selectedDef.fqn"
            >
              {{ selectedDef.fqn }}
            </span>
          </div>
        </div>

        <!-- Jump to definition + project-wide search -->
        <div class="gl-flex gl-flex-wrap gl-gap-2">
          <gl-button
            v-if="blobUrl(selectedDef.file_path, selectedDef.start_line)"
            :href="blobUrl(selectedDef.file_path, selectedDef.start_line)"
            category="secondary"
            size="small"
            icon="arrow-right"
          >
            {{ $options.i18n.jumpToDefinition }}
          </gl-button>
          <gl-button
            v-if="projectSearchUrl(selectedDef.name)"
            v-gl-tooltip
            data-testid="project-search-button"
            :href="projectSearchUrl(selectedDef.name)"
            :title="searchActionTitle"
            :aria-label="searchActionTitle"
            category="tertiary"
            size="small"
            icon="search"
          />
        </div>

        <!-- Tabs: References / Calls -->
        <div>
          <div class="gl-border-b gl-mb-3 gl-flex gl-border-default">
            <button
              data-testid="references-tab"
              type="button"
              class="gl-mr-4 gl-cursor-pointer gl-border-0 gl-border-b-2 gl-bg-transparent gl-px-1 gl-pb-2 gl-text-sm"
              :class="
                activeTab === 'references'
                  ? 'gl-border-strong gl-font-semibold gl-text-default'
                  : 'gl-border-transparent gl-text-subtle'
              "
              @click="activeTab = 'references'"
            >
              {{ $options.i18n.references }}
              <span v-if="!loadingRefs && references.length" class="gl-ml-1"
                >({{ references.length }})</span
              >
              <gl-loading-icon v-else-if="loadingRefs" size="sm" inline class="gl-ml-1" />
            </button>
            <button
              data-testid="calls-tab"
              type="button"
              class="gl-cursor-pointer gl-border-0 gl-border-b-2 gl-bg-transparent gl-px-1 gl-pb-2 gl-text-sm"
              :class="
                activeTab === 'calls'
                  ? 'gl-border-strong gl-font-semibold gl-text-default'
                  : 'gl-border-transparent gl-text-subtle'
              "
              @click="activeTab = 'calls'"
            >
              {{ $options.i18n.calls }}
              <span v-if="!loadingCallees && callees.length" class="gl-ml-1"
                >({{ callees.length }})</span
              >
              <gl-loading-icon v-else-if="loadingCallees" size="sm" inline class="gl-ml-1" />
            </button>
          </div>

          <!-- References tab -->
          <template v-if="activeTab === 'references'">
            <p
              v-if="!loadingRefs && !references.length"
              data-testid="no-references"
              class="gl-m-0 gl-text-sm gl-text-subtle"
            >
              {{ $options.i18n.noReferences }}
            </p>
            <ul
              v-else-if="references.length"
              data-testid="references-list"
              class="gl-m-0 gl-flex gl-list-none gl-flex-col gl-gap-3 gl-p-0"
            >
              <li v-for="group in referencesByFile" :key="group.filePath">
                <div
                  class="gl-font-mono gl-mb-1 gl-truncate gl-text-xs gl-text-subtle"
                  :title="group.filePath"
                >
                  {{ group.filePath }}
                </div>
                <ul class="gl-m-0 gl-flex gl-list-none gl-flex-col gl-gap-1 gl-p-0">
                  <li v-for="ref in group.refs" :key="ref.id">
                    <a
                      :href="blobUrl(ref.file_path, ref.start_line)"
                      class="gl-flex gl-items-center gl-gap-2 gl-rounded-base gl-px-2 gl-py-1 gl-no-underline hover:gl-bg-subtle hover:gl-no-underline"
                    >
                      <gl-icon
                        :name="typeIcon(ref.definition_type)"
                        :size="14"
                        :variant="typeVariant(ref.definition_type)"
                        class="gl-shrink-0"
                      />
                      <span class="gl-font-mono gl-truncate gl-text-sm gl-text-default">{{
                        ref.name
                      }}</span>
                      <span class="gl-ml-auto gl-shrink-0 gl-text-xs gl-text-subtle">{{
                        lineLabel(ref.start_line)
                      }}</span>
                    </a>
                  </li>
                </ul>
              </li>
            </ul>
          </template>

          <!-- Calls tab -->
          <template v-else-if="activeTab === 'calls'">
            <p
              v-if="!loadingCallees && !callees.length"
              data-testid="no-calls"
              class="gl-m-0 gl-text-sm gl-text-subtle"
            >
              {{ $options.i18n.noCalls }}
            </p>
            <ul
              v-else-if="callees.length"
              data-testid="calls-list"
              class="gl-m-0 gl-flex gl-list-none gl-flex-col gl-gap-3 gl-p-0"
            >
              <li v-for="group in calleesByFile" :key="group.filePath">
                <div
                  class="gl-font-mono gl-mb-1 gl-truncate gl-text-xs gl-text-subtle"
                  :title="group.filePath"
                >
                  {{ group.filePath }}
                </div>
                <ul class="gl-m-0 gl-flex gl-list-none gl-flex-col gl-gap-1 gl-p-0">
                  <li v-for="callee in group.refs" :key="callee.id">
                    <a
                      :href="blobUrl(callee.file_path, callee.start_line)"
                      class="gl-flex gl-items-center gl-gap-2 gl-rounded-base gl-px-2 gl-py-1 gl-no-underline hover:gl-bg-subtle hover:gl-no-underline"
                    >
                      <gl-icon
                        :name="typeIcon(callee.definition_type)"
                        :size="14"
                        :variant="typeVariant(callee.definition_type)"
                        class="gl-shrink-0"
                      />
                      <span class="gl-font-mono gl-truncate gl-text-sm gl-text-default">{{
                        callee.name
                      }}</span>
                      <span class="gl-ml-auto gl-shrink-0 gl-text-xs gl-text-subtle">{{
                        lineLabel(callee.start_line)
                      }}</span>
                    </a>
                  </li>
                </ul>
              </li>
            </ul>
          </template>
        </div>
      </div>
    </template>
    <template #footer>
      <a
        :href="$options.i18n.feedbackUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="gl-text-sm gl-text-subtle hover:gl-text-default"
        >{{ $options.i18n.leaveFeedback }}</a
      >
    </template>
  </crud-component>
</template>
