<script>
import {
  GlBadge,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadioGroup,
  GlFormRadio,
  GlIcon,
  GlTable,
  GlLabel,
  GlButton,
  GlTooltipDirective,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlLink,
  GlPopover,
  GlEmptyState,
} from '@gitlab/ui';
import EMPTY_ATTRIBUTE_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-labels-md.svg?url';
import { s__, __, sprintf } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import {
  defaultCategory,
  CATEGORY_EDITABLE,
  CATEGORY_PARTIALLY_EDITABLE,
  CATEGORY_LOCKED,
  RECENTLY_SAVED_TIMEOUT,
} from './constants';

export default {
  name: 'CategoryForm',
  components: {
    GlBadge,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlFormRadioGroup,
    GlFormRadio,
    GlIcon,
    GlTable,
    GlLabel,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    CrudComponent,
    GlLink,
    GlPopover,
    GlEmptyState,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    selectedCategory: {
      type: Object,
      required: false,
      default: () => defaultCategory,
    },
    unsavedAttributes: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: [
    'add-attribute',
    'delete-attribute',
    'delete-category',
    'edit-attribute',
    'save-category',
  ],
  data() {
    return {
      category: {
        name: '',
        description: '',
      },
      formErrors: {
        name: null,
        multipleSelection: null,
        attributes: null,
      },
      originalCategory: {},
      recentlySaved: false,
    };
  },
  computed: {
    isNew() {
      return !this.category?.id;
    },
    isLocked() {
      return this.category?.editableState === CATEGORY_LOCKED;
    },
    isLimited() {
      return this.category?.editableState === CATEGORY_PARTIALLY_EDITABLE;
    },
    isCategoryEditable() {
      return this.category?.editableState === CATEGORY_EDITABLE || this.isNew;
    },
    areAttributesEditable() {
      return !this.isLocked || this.isNew;
    },
    attributes() {
      return [...(this.category?.securityAttributes || []), ...this.unsavedAttributes];
    },
    unsavedChanges() {
      const changes = [];

      if (!Object.keys(this.originalCategory).length) return changes;

      if (this.category.name !== this.originalCategory.name) {
        changes.push(s__('SecurityAttributes|Updated the category name'));
      }
      if (this.category.description !== this.originalCategory.description) {
        changes.push(s__('SecurityAttributes|Updated the category description'));
      }
      if (this.category.multipleSelection !== this.originalCategory.multipleSelection) {
        changes.push(s__('SecurityAttributes|Changed the selection type'));
      }

      if (this.unsavedAttributes?.length) {
        this.unsavedAttributes.forEach((attr) => {
          changes.push(
            sprintf(s__('SecurityAttributes|Created the attribute "%{name}"'), { name: attr.name }),
          );
        });
      }

      return changes;
    },

    unsavedCount() {
      return this.unsavedChanges.length;
    },
  },
  watch: {
    selectedCategory(newCategory) {
      this.category = newCategory;
      this.originalCategory = JSON.parse(JSON.stringify(newCategory));

      this.formErrors.name = null;
      this.formErrors.multipleSelection = null;
      this.formErrors.attributes = null;
    },
  },
  mounted() {
    this.category = this.selectedCategory || defaultCategory;
    this.originalCategory = JSON.parse(JSON.stringify(this.category));
  },
  destroyed() {
    if (this.recentlySavedTimeout) {
      clearTimeout(this.recentlySavedTimeout);
    }
  },
  methods: {
    isFormValid() {
      this.formErrors.name =
        this.category.name.trim() === '' ? s__('SecurityAttributes|Name is required') : null;
      this.formErrors.multipleSelection =
        this.category.multipleSelection === null
          ? s__('SecurityAttributes|Selection type is required')
          : null;
      this.formErrors.attributes = !this.attributes.length
        ? s__('SecurityAttributes|At least one attribute is required')
        : null;
      return (
        !this.formErrors.name && !this.formErrors.multipleSelection && !this.formErrors.attributes
      );
    },
    handleSubmit() {
      if (!this.isFormValid()) return;
      this.$emit('save-category', this.category);
      this.originalCategory = JSON.parse(JSON.stringify(this.category));

      // show "All changes saved" briefly like a toast
      this.recentlySaved = true;
      clearTimeout(this.recentlySavedTimeout);
      this.recentlySavedTimeout = setTimeout(() => {
        this.recentlySaved = false;
      }, RECENTLY_SAVED_TIMEOUT);
    },
  },
  attributesTableFields: [
    {
      key: 'name',
      label: s__('SecurityAttributes|Attribute'),
      // eslint-disable-next-line @gitlab/require-i18n-strings
      tdClass: '!gl-border-b-0 gl-md-w-1/5',
      // eslint-disable-next-line @gitlab/require-i18n-strings
      thClass: '!gl-border-t-0 gl-md-w-1/5',
    },
    {
      key: 'description',
      label: __('Description'),
      tdClass: '!gl-border-b-0 gl-md-w-[55%]',
      thClass: '!gl-border-t-0 gl-md-w-[55%]',
    },
    /* To be added later
    {
      key: 'usedBy',
      label: __('Used by'),
      tdClass: '!gl-border-b-0 gl-md-w-[15%]',
      thClass: '!gl-border-t-0 gl-md-w-[15%]',
    }, */
    {
      key: 'actions',
      label: '',
      tdClass: '!gl-border-b-0 gl-md-w-[10%] gl-text-right',
      thClass: '!gl-border-t-0 gl-md-w-[10%]',
    },
  ],
  editItem: {
    text: __('Edit'),
  },
  deleteItem: {
    text: __('Delete'),
  },
  singleSelection: s__('SecurityAttributes|Single selection'),
  multipleSelection: s__('SecurityAttributes|Multiple selection'),
  EMPTY_ATTRIBUTE_SVG,
};
</script>
<template>
  <div>
    <div class="gl-p-6">
      <div class="gl-float-right">
        <gl-badge
          v-if="isLocked"
          v-gl-tooltip="
            s__(
              'SecurityAttributes|You cannot delete or edit this category. You cannot modify the attributes.',
            )
          "
          icon="lock"
        >
          {{ s__('SecurityAttributes|Category locked') }}
        </gl-badge>
        <gl-badge
          v-else-if="isLimited"
          v-gl-tooltip="
            s__(
              'SecurityAttributes|You cannot delete this category, but you can edit the attributes.',
            )
          "
          icon="pencil"
        >
          {{ s__('SecurityAttributes|Limited edits allowed') }}
        </gl-badge>
        <gl-disclosure-dropdown v-else-if="!isNew" category="tertiary" icon="ellipsis_v" no-caret>
          <gl-disclosure-dropdown-item
            :item="$options.deleteItem"
            data-testid="delete-category-item"
            @action="$emit('delete-category', category)"
          />
        </gl-disclosure-dropdown>
      </div>
      <h3 class="gl-heading-3" data-testid="category-form-title">
        {{ isNew ? s__('SecurityAttributes|Category details') : category.name }}
      </h3>
      <p>{{ s__('SecurityAttributes|View category settings and associated attributes.') }}</p>
      <gl-form @submit.prevent>
        <gl-form-group
          :label="s__('SecurityAttributes|Name')"
          :state="formErrors.name === null"
          :invalid-feedback="formErrors.name"
          data-testid="category-name-group"
        >
          <gl-form-input
            v-if="isCategoryEditable"
            v-model="category.name"
            :state="formErrors.name === null"
            data-testid="category-name-input"
          />
          <span v-else>{{ category.name }}</span>
        </gl-form-group>
        <gl-form-group :label="__('Description')">
          <gl-form-textarea v-if="isCategoryEditable" v-model="category.description" />
          <span v-else>{{ category.description }}</span>
        </gl-form-group>
        <gl-form-group
          :state="formErrors.multipleSelection === null"
          :invalid-feedback="formErrors.multipleSelection"
          data-testid="selection-type-group"
        >
          <template #label>
            {{ s__('SecurityAttributes|Selection type') }}
            <gl-icon
              v-gl-tooltip="
                s__(
                  'SecurityAttributes|You cannot change the selection type after the category is created. To use a different selection type, create a new category.',
                )
              "
              variant="info"
              name="information-o"
            />
          </template>
          <gl-form-radio-group
            v-if="isNew"
            v-model="category.multipleSelection"
            data-testid="selection-type-input"
          >
            <gl-form-radio :value="false" class="gl-z-0">
              {{ $options.singleSelection }}
            </gl-form-radio>
            <gl-form-radio :value="true" class="gl-z-0">
              {{ $options.multipleSelection }}
            </gl-form-radio>
          </gl-form-radio-group>
          <span v-else>
            {{ category.multipleSelection ? $options.multipleSelection : $options.singleSelection }}
          </span>
        </gl-form-group>
        <gl-button
          v-if="areAttributesEditable"
          category="secondary"
          variant="confirm"
          size="small"
          class="gl-float-right"
          data-testid="add-attribute-button"
          @click="$emit('add-attribute')"
        >
          {{ s__('SecurityAttributes|Create attribute') }}
        </gl-button>
        <gl-form-group
          :description="s__('SecurityAttributes|View the attributes available in this category')"
          :state="formErrors.attributes === null"
          :invalid-feedback="formErrors.attributes"
          data-testid="attributes-group"
        >
          <template #label>
            {{ s__('SecurityAttributes|Attributes') }}
            <span class="gl-font-normal gl-text-subtle">
              <gl-icon name="label" />
              {{ attributes.length }}
            </span>
          </template>
        </gl-form-group>
        <crud-component header-class="gl-hidden">
          <gl-table
            :items="attributes"
            :fields="$options.attributesTableFields"
            stacked="md"
            class="gl-mb-0"
            show-empty
          >
            <template #empty>
              <gl-empty-state
                :svg-path="$options.EMPTY_ATTRIBUTE_SVG"
                :svg-height="100"
                :title="__('There are no attributes in this category.')"
                :description="__('Attributes you create will appear here.')"
                ><template v-if="areAttributesEditable" #actions>
                  <gl-button variant="confirm" @click="$emit('add-attribute')">
                    {{ s__('SecurityAttributes|Create attribute') }}
                  </gl-button>
                </template>
              </gl-empty-state>
            </template>

            <template #cell(name)="{ item: { name, color } }">
              <gl-label :background-color="color" :title="name" />
            </template>
            <template #cell(usedBy)="{ item: { projectCount } }">
              <gl-link v-if="!isNaN(projectCount)">
                {{ n__('%d project', '%d projects', projectCount) }}
              </gl-link>
            </template>
            <template v-if="areAttributesEditable" #cell(actions)="{ item }">
              <gl-disclosure-dropdown category="tertiary" icon="ellipsis_v" no-caret>
                <gl-disclosure-dropdown-item
                  v-if="item.id"
                  :item="$options.editItem"
                  data-testid="edit-attribute-item"
                  @action="$emit('edit-attribute', item)"
                />
                <gl-disclosure-dropdown-item
                  :item="$options.deleteItem"
                  data-testid="delete-attribute-item"
                  @action="$emit('delete-attribute', item)"
                />
              </gl-disclosure-dropdown>
            </template>
          </gl-table>
        </crud-component>
      </gl-form>
    </div>
    <div
      v-if="!isLocked"
      class="gl-border-t gl-sticky gl-bottom-0 gl-flex gl-w-full gl-items-center gl-bg-default gl-p-6"
    >
      <gl-button
        category="primary"
        variant="confirm"
        data-testid="save-button"
        @click="handleSubmit"
      >
        {{ s__('SecurityAttributes|Save changes') }}
      </gl-button>

      <div
        id="unsaved-changes-container"
        data-testid="unsaved-changes-container"
        class="gl-ml-5 gl-flex gl-items-center gl-text-sm gl-text-subtle"
      >
        <template v-if="unsavedCount > 0">
          <gl-icon name="warning" variant="warning" class="gl-mr-2" />
          <span class="gl-link hover:gl-underline">
            <span> {{ n__('%d unsaved change', '%d unsaved changes', unsavedCount) }}</span>
          </span>
          <gl-popover placement="top" target="unsaved-changes-container">
            <template #title>
              {{ s__('SecurityAttributes|Unsaved changes') }}
            </template>
            <ul class="gl-mb-0 gl-pl-3">
              <li
                v-for="(change, index) in unsavedChanges"
                :key="index"
                class="gl-ml-2 gl-list-disc"
              >
                {{ change }}
              </li>
            </ul>
          </gl-popover>
        </template>
        <template v-if="unsavedCount === 0 && recentlySaved">
          <gl-icon name="check" variant="success" class="gl-mr-2" />
          <span>
            {{ s__('SecurityAttributes|All changes saved') }}
          </span>
        </template>
      </div>
    </div>
  </div>
</template>
