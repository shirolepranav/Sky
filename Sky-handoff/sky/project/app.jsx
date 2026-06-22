// App — assembles the canvas with sections and artboards.

function PhoneFrame({ children }) {
  return (
    <div style={{
      width: '100%', height: '100%',
      background: '#F0EDE5',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <IOSDevice>{children}</IOSDevice>
    </div>
  );
}

function App() {
  return (
    <DesignCanvas>
      <DCSection id="foundations" title="Foundations"
        subtitle="Color, type, mascot — the system at a glance.">
        <DCArtboard id="foundations" label="Design system" width={820} height={1080}>
          <FoundationsCard />
        </DCArtboard>
      </DCSection>

      <DCSection id="today" title="Today tab"
        subtitle="The most-viewed screen — the blocked state, warm and Nimbus-first.">
        <DCArtboard id="today-cozy" label="Today · blocked" width={440} height={920}>
          <PhoneFrame><TodayCozy /></PhoneFrame>
        </DCArtboard>
      </DCSection>

      <DCSection id="shield" title="Custom shield"
        subtitle="The moment the apps stop — a warm invitation back outside.">
        <DCArtboard id="shield-warm" label="Custom shield" width={440} height={920}>
          <PhoneFrame><ShieldWarm /></PhoneFrame>
        </DCArtboard>
      </DCSection>

      <DCSection id="verify" title="Verification"
        subtitle="The product's defining act — 30 seconds, sensors fused on-device, then the payoff.">
        <DCArtboard id="verify-recording" label="Recording · 14s of 30s" width={440} height={920}>
          <PhoneFrame><VerificationRecording /></PhoneFrame>
        </DCArtboard>
        <DCArtboard id="verify-success" label="Success · streak +1" width={440} height={920}>
          <PhoneFrame><VerificationSuccess /></PhoneFrame>
        </DCArtboard>
      </DCSection>

      <DCSection id="emergency" title="Emergency unlock"
        subtitle="Honest friction. No paste, 20-char minimum, 5s wait, clear consequences.">
        <DCArtboard id="emergency-typed" label="Typed reason · ready to confirm" width={440} height={920}>
          <PhoneFrame><EmergencyUnlock /></PhoneFrame>
        </DCArtboard>
      </DCSection>

      <DCSection id="streaks" title="Streaks tab"
        subtitle="The longitudinal payoff. Local + CloudKit only — no leaderboards in v1.0.">
        <DCArtboard id="streaks" label="13 day streak · 4 of 10 badges" width={440} height={920}>
          <PhoneFrame><StreaksScreen /></PhoneFrame>
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
