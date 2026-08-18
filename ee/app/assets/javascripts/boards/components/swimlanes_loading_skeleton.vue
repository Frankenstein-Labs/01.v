<script>
import BoardCardLoadingSkeleton from '~/boards/components/board_card_loading_skeleton.vue';

export default {
  name: 'SwimlanesLoadingSkeleton',
  components: {
    BoardCardLoadingSkeleton,
  },
};
</script>

<template>
  <div class="gl-px-3">
    <div v-for="i in 3" :key="i" class="gl-mt-6 gl-flex gl-rounded-lg gl-bg-gray-100">
      <div v-for="j in 4" :key="j" class="gl-px-3 gl-pt-3">
        <board-card-loading-skeleton />
      </div>
    </div>
  </div>
</template>
