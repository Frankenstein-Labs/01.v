<script>
import { GlLoadingIcon } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ModelInfo from 'ee/admin/data_management_item/components/model_info.vue';
import { getModel, putModelAction } from 'ee/api/data_management_api';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { createAlert } from '~/alert';
import { sprintf, s__ } from '~/locale';
import ChecksumInfo from 'ee/admin/data_management_item/components/checksum_info.vue';
import showToast from '~/vue_shared/plugins/global_toast';

export default {
  name: 'AdminDataManagementItemApp',
  components: {
    PageHeading,
    ChecksumInfo,
    ModelInfo,
    GlLoadingIcon,
  },
  props: {
    modelTypeData: {
      type: Object,
      required: true,
    },
    modelId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      model: null,
      isLoading: true,
      checksumLoading: false,
    };
  },
  computed: {
    name() {
      return `${this.modelTypeData.modelClass}/${this.modelId}`;
    },
    checksumInformation() {
      return this.model?.checksumInformation ?? {};
    },
  },
  created() {
    this.initializeModel();
  },
  methods: {
    async initializeModel() {
      try {
        const { data } = await getModel(this.modelTypeData.namePlural, this.modelId);
        this.model = convertObjectPropsToCamelCase(data, { deep: true });
      } catch (error) {
        createAlert({
          message: sprintf(
            s__('Geo|There was an error fetching %{model}. Please refresh the page and try again.'),
            { model: this.name },
          ),
          captureError: true,
          error,
        });
      } finally {
        this.isLoading = false;
      }
    },
    async handleRecalculateChecksum() {
      this.checksumLoading = true;

      try {
        const { data } = await putModelAction(
          this.modelTypeData.namePlural,
          this.modelId,
          'checksum',
        );
        this.model = convertObjectPropsToCamelCase(data, { deep: true });

        showToast(
          sprintf(s__('Geo|Successfully recalculated checksum for %{name}.'), { name: this.name }),
        );
      } catch (error) {
        this.handleChecksumError(error);
      } finally {
        this.checksumLoading = false;
      }
    },
    handleChecksumError(error) {
      createAlert({
        message: sprintf(s__('Geo|There was an error recalculating checksum for %{name}.'), {
          name: this.name,
        }),
        captureError: true,
        error,
      });
    },
  },
};
</script>

<template>
  <section>
    <page-heading :heading="name" />
    <gl-loading-icon v-if="isLoading" size="xl" class="gl-mt-4" />
    <div v-else-if="model" class="gl-grid gl-gap-4 @md/panel:gl-grid-cols-2">
      <checksum-info
        v-if="modelTypeData.checksumEnabled"
        class="gl-order-2 @md/panel:gl-order-1"
        :details="checksumInformation"
        :checksum-loading="checksumLoading"
        @recalculate-checksum="handleRecalculateChecksum"
      />
      <model-info class="gl-order-1 @md/panel:gl-order-2" :model="model" />
    </div>
  </section>
</template>
