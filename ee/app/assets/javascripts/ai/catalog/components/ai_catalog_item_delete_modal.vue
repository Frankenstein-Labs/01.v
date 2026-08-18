<script>
import { GlFormRadioGroup, GlFormRadio, GlSprintf } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { AI_CATALOG_ITEM_LABELS } from '../constants';
import { canDeleteAiCatalogItem } from '../permissions';

export default {
  name: 'AiCatalogItemDeleteModal',
  components: {
    GlFormRadioGroup,
    GlFormRadio,
    GlSprintf,
    ConfirmActionModal,
  },
  mixins: [glAbilitiesMixin()],
  props: {
    item: {
      type: Object,
      required: true,
    },
    deleteFn: {
      type: Function,
      required: true,
    },
  },
  emits: ['close'],
  data() {
    return {
      forceHardDelete: false,
    };
  },
  computed: {
    canHardDelete() {
      return canDeleteAiCatalogItem({ glAbilities: this.glAbilities });
    },
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.item.itemType];
    },
    deleteConfirmTitle() {
      return this.canHardDelete
        ? sprintf(s__('AICatalog|Delete %{itemType}'), { itemType: this.itemTypeLabel })
        : sprintf(s__('AICatalog|Hide %{itemType}'), { itemType: this.itemTypeLabel });
    },
    deleteConfirmMessage() {
      return this.canHardDelete
        ? s__('AICatalog|Are you sure you want to delete %{itemType} %{name}?')
        : s__('AICatalog|Are you sure you want to hide %{itemType} %{name}?');
    },
    deleteConfirmAdditionalMessage() {
      if (!this.canHardDelete) {
        return sprintf(
          s__(
            'AICatalog|Users can continue to use the %{itemType} in the groups and projects it is enabled in.',
          ),
          { itemType: this.itemTypeLabel },
        );
      }
      return null;
    },
  },
  created() {
    this.forceHardDelete = this.canHardDelete;
  },
};
</script>

<template>
  <confirm-action-modal
    modal-id="delete-item-modal"
    data-testid="delete-item-modal"
    variant="danger"
    :title="deleteConfirmTitle"
    :action-fn="() => deleteFn(forceHardDelete)"
    :action-text="__('Confirm')"
    @close="$emit('close')"
  >
    <gl-sprintf :message="deleteConfirmMessage">
      <template #name>
        <strong class="gl-wrap-anywhere">{{ item.name }}</strong>
      </template>
      <template #itemType>{{ itemTypeLabel }}</template>
    </gl-sprintf>
    <p v-if="deleteConfirmAdditionalMessage" class="gl-mb-0 gl-mt-3 gl-text-subtle">
      {{ deleteConfirmAdditionalMessage }}
    </p>
    <div v-if="canHardDelete">
      <label for="delete-method" class="gl-mb-0 gl-mt-4 gl-block">
        {{ s__('AICatalog|Deletion method') }}
      </label>
      <p class="gl-mb-3 gl-text-subtle">
        <gl-sprintf :message="s__('AICatalog|Choose whether to delete or hide this %{itemType}.')">
          <template #itemType>{{ itemTypeLabel }}</template>
        </gl-sprintf>
      </p>
      <gl-form-radio-group id="delete-method" v-model="forceHardDelete">
        <gl-form-radio :value="true">
          {{ s__('AICatalog|Delete permanently') }}
          <template #help>
            {{ s__('AICatalog|This action cannot be undone.') }}
          </template>
        </gl-form-radio>
        <gl-form-radio :value="false">
          {{ s__('AICatalog|Hide from the AI Catalog') }}
          <template #help>
            {{
              sprintf(
                s__(
                  'AICatalog|Users can continue to use the %{itemType} in the groups and projects it is enabled in.',
                ),
                { itemType: itemTypeLabel },
              )
            }}
          </template>
        </gl-form-radio>
      </gl-form-radio-group>
    </div>
  </confirm-action-modal>
</template>
