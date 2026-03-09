export interface SenseKitStateSnapshot {
  device_id: string;
  updated_at: string;
  last_event_type: string;
}

export function formatSenseKitStatus(snapshot: SenseKitStateSnapshot): string {
  return `SenseKit ${snapshot.device_id} last event: ${snapshot.last_event_type} at ${snapshot.updated_at}`;
}

