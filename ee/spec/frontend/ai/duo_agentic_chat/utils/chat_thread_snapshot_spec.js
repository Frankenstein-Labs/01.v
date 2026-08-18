import {
  saveThreadSnapshot,
  loadThreadSnapshot,
  clearThreadSnapshot,
} from 'ee/ai/duo_agentic_chat/utils/chat_thread_snapshot';

describe('Chat Snapshot', () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  afterEach(() => {
    sessionStorage.clear();
  });

  describe('saveThreadSnapshot', () => {
    const workflowId = 'workflow-123';
    const messages = [
      { role: 'user', content: 'Hello' },
      { role: 'assistant', content: 'Hi there!' },
    ];

    describe('when called with valid messages', () => {
      it('saves messages to sessionStorage with correct key', () => {
        saveThreadSnapshot(workflowId, messages);

        const item = sessionStorage.getItem(`chat/${workflowId}`);
        expect(item).not.toBeNull();
      });

      it('saves snapshot with convoId, and messages', () => {
        saveThreadSnapshot(workflowId, messages);

        const savedData = JSON.parse(sessionStorage.getItem(`chat/${workflowId}`));
        expect(savedData).toEqual({
          convoId: workflowId,
          messages,
        });
      });
    });

    describe('when messages array is empty', () => {
      it('saves snapshot with lastTs as 0', () => {
        saveThreadSnapshot(workflowId, []);

        const savedData = JSON.parse(sessionStorage.getItem(`chat/${workflowId}`));
        expect(savedData.messages).toEqual([]);
      });
    });

    describe('when messages exceed 20 limit', () => {
      it('saves only last 20 messages', () => {
        const manyMessages = Array.from({ length: 50 }, (_, i) => ({
          role: i % 2 === 0 ? 'user' : 'assistant',
          content: `Message ${i}`,
        }));

        saveThreadSnapshot(workflowId, manyMessages);

        const savedData = JSON.parse(sessionStorage.getItem(`chat/${workflowId}`));
        expect(savedData.messages).toHaveLength(20);
        expect(savedData.messages[0]).toEqual(manyMessages[30]); // First of last 20
        expect(savedData.messages[19]).toEqual(manyMessages[49]); // Last message
      });
    });

    describe('when sessionStorage quota is exceeded', () => {
      it('silently ignores the error', () => {
        jest.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
          throw new Error('QuotaExceededError');
        });

        expect(() => saveThreadSnapshot(workflowId, messages)).not.toThrow();

        Storage.prototype.setItem.mockRestore();
      });
    });

    describe('when sessionStorage throws any error', () => {
      it('silently ignores the error', () => {
        jest.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
          throw new Error('Some error');
        });

        expect(() => saveThreadSnapshot(workflowId, messages)).not.toThrow();

        Storage.prototype.setItem.mockRestore();
      });
    });
  });

  describe('loadThreadSnapshot', () => {
    const workflowId = 'workflow-456';

    describe('when snapshot exists', () => {
      it('returns the snapshot data', () => {
        const snapshot = {
          v: 1,
          convoId: workflowId,
          lastTs: 3000,
          messages: [
            { role: 'user', content: 'Hello', ts: 1000 },
            { role: 'assistant', content: 'Hi!', ts: 2000 },
          ],
        };

        sessionStorage.setItem(`chat/${workflowId}`, JSON.stringify(snapshot));

        const result = loadThreadSnapshot(workflowId);

        expect(result).toEqual(snapshot);
      });
    });

    describe('when snapshot does not exist', () => {
      it('returns null', () => {
        const result = loadThreadSnapshot(workflowId);

        expect(result).toBeNull();
      });
    });

    describe('when JSON parsing fails', () => {
      it('returns null', () => {
        sessionStorage.setItem(`chat/${workflowId}`, 'invalid json{');

        const result = loadThreadSnapshot(workflowId);

        expect(result).toBeNull();
      });
    });

    describe('when sessionStorage throws error', () => {
      it('returns null', () => {
        jest.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
          throw new Error('Storage error');
        });

        const result = loadThreadSnapshot(workflowId);

        expect(result).toBeNull();

        Storage.prototype.getItem.mockRestore();
      });
    });
  });

  describe('clearThreadSnapshot', () => {
    const workflowId = 'workflow-789';

    describe('when called', () => {
      it('removes the snapshot from sessionStorage', () => {
        sessionStorage.setItem(`chat/${workflowId}`, JSON.stringify({ test: 'data' }));

        clearThreadSnapshot(workflowId);

        const item = sessionStorage.getItem(`chat/${workflowId}`);
        expect(item).toBeNull();
      });
    });

    describe('when sessionStorage throws error', () => {
      it('silently ignores the error', () => {
        jest.spyOn(Storage.prototype, 'removeItem').mockImplementation(() => {
          throw new Error('Storage error');
        });

        expect(() => clearThreadSnapshot(workflowId)).not.toThrow();

        Storage.prototype.removeItem.mockRestore();
      });
    });
  });

  describe('integration scenarios', () => {
    const workflowId = 'workflow-integration';

    it('saves and loads messages correctly', () => {
      const messages = [
        { role: 'user', content: 'Test message' },
        { role: 'assistant', content: 'Response' },
      ];

      saveThreadSnapshot(workflowId, messages);
      const loaded = loadThreadSnapshot(workflowId);

      expect(loaded.messages).toEqual(messages);
      expect(loaded.convoId).toBe(workflowId);
    });

    it('clears saved snapshot', () => {
      const messages = [{ role: 'user', content: 'Test' }];

      saveThreadSnapshot(workflowId, messages);
      expect(loadThreadSnapshot(workflowId)).not.toBeNull();

      clearThreadSnapshot(workflowId);
      expect(loadThreadSnapshot(workflowId)).toBeNull();
    });

    it('handles multiple workflows independently', () => {
      const workflow1 = 'workflow-1';
      const workflow2 = 'workflow-2';
      const messages1 = [{ role: 'user', content: 'Workflow 1' }];
      const messages2 = [{ role: 'user', content: 'Workflow 2' }];

      saveThreadSnapshot(workflow1, messages1);
      saveThreadSnapshot(workflow2, messages2);

      const loaded1 = loadThreadSnapshot(workflow1);
      const loaded2 = loadThreadSnapshot(workflow2);

      expect(loaded1.messages[0].content).toBe('Workflow 1');
      expect(loaded2.messages[0].content).toBe('Workflow 2');

      clearThreadSnapshot(workflow1);

      expect(loadThreadSnapshot(workflow1)).toBeNull();
      expect(loadThreadSnapshot(workflow2)).not.toBeNull();
    });
  });
});
