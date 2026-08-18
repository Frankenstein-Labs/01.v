import { s__ } from '~/locale';

export const CLIENT_TYPES = {
  GITLAB_DUO: {
    name: s__('AgentArtifacts|GitLab Duo'),
    icon: 'tanuki-ai',
  },
  // Example of how to add a new client type once supported by the backend.
  // Note: future client types may require an image URL instead of a sprite icon
  // if a matching icon is not available in @gitlab/svgs.
  // CURSOR: { name: s__('AgentArtifacts|Cursor'), icon: 'cursor' },
};

export const DEFAULT_CLIENT_TYPE = CLIENT_TYPES.GITLAB_DUO;
