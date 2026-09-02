function ratio(numerator, denominator) {
  return denominator > 0 ? Number((numerator / denominator).toFixed(4)) : 0;
}

export function aggregateEvents(events, hours = 168) {
  const sessions = new Set();
  const eventCounts = {};
  const sessionEvents = new Map();

  for (const row of events ?? []) {
    const sessionId = row.session_id || row.sessionId;
    const eventName = row.event_name || row.event;
    if (!sessionId || !eventName) continue;
    sessions.add(sessionId);
    eventCounts[eventName] = (eventCounts[eventName] || 0) + 1;
    if (!sessionEvents.has(eventName)) sessionEvents.set(eventName, new Set());
    sessionEvents.get(eventName).add(sessionId);
  }

  const uniqueSessions = sessions.size;
  const sessionCount = (name) => sessionEvents.get(name)?.size ?? 0;
  const cycleSessions = sessionCount("CompanyCycleCompleted");
  const missionStartSessions = sessionCount("MissionStarted");
  const missionCompleteSessions = sessionCount("MissionCompleted");
  const offerSessions = sessionCount("OfferPrompted");
  const purchaseSessions = sessionCount("PurchaseGranted") + sessionCount("PassConfirmed");

  return {
    windowHours: hours,
    eventRows: events?.length ?? 0,
    uniqueSessions,
    eventCounts,
    rates: {
      coreLoopActivation: ratio(cycleSessions, uniqueSessions),
      missionAdoption: ratio(missionStartSessions, cycleSessions || uniqueSessions),
      missionCompletion: ratio(missionCompleteSessions, missionStartSessions),
      offerEngagement: ratio(offerSessions, uniqueSessions),
      confirmedPurchaseSessionRate: ratio(purchaseSessions, uniqueSessions),
      offerToConfirmedPurchase: ratio(purchaseSessions, offerSessions),
    },
    confirmedPurchaseSignals: {
      developerProductReceipts: eventCounts.PurchaseGranted || 0,
      gamePassConfirmations: eventCounts.PassConfirmed || 0,
      total: (eventCounts.PurchaseGranted || 0) + (eventCounts.PassConfirmed || 0),
      caveat: "Signals are not booked Robux revenue. Reconcile financial totals in Roblox Creator Hub.",
    },
  };
}
