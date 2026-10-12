<?php
declare(strict_types=1);

// Loads only XF's actual upgrade trait, never the configured XenForo app/DB.
namespace XF\AddOn {
    abstract class AbstractSetup { public $addOn; }
    trait StepRunnerInstallTrait {}
    trait StepRunnerUninstallTrait {}
}
namespace {
    final class XF
    {
        public static function db() { throw new RuntimeException('Upgrade attempted a database mutation'); }
        public static function app() { throw new RuntimeException('Upgrade bootstrapped the configured app'); }
    }
    final class InstalledAddonFixture
    {
        public function __construct(public int $version_id) {}
        public function getLastActionStep(string $action) { return null; }
    }
    final class AddonFixture
    {
        public array $updates = [];
        public function __construct(public InstalledAddonFixture $installed) {}
        public function getInstalledAddOn(): InstalledAddonFixture { return $this->installed; }
        public function updatePendingAction($action, $step): void { $this->updates[] = [$action, $step]; }
    }
    $sourceRoot = $argv[1] ?? (getenv('CHAT_SYNC_XF_SOURCE_ROOT') ?: 'C:/xampp/htdocs/ekitapligim/src');
    $traitPath = rtrim($sourceRoot, '/\\') . '/XF/AddOn/StepRunnerUpgradeTrait.php';
    if (!is_file($traitPath)) { throw new RuntimeException('Supply the local XenForo src root; no web/DB bootstrap is used.'); }
    require $traitPath;
    require __DIR__ . '/../../Backend/IosApi-addon/Setup.php';
    foreach ([1000032, 1000033] as $installedVersion)
    {
        $setup = new \Ekitapligim\IosApi\Setup();
        $fixture = new AddonFixture(new InstalledAddonFixture($installedVersion));
        $setup->addOn = $fixture;
        if ($setup->upgrade() !== null || $fixture->updates !== [])
        {
            throw new RuntimeException('Unexpected migration/step when upgrading from ' . $installedVersion);
        }
    }
    echo "PASS: actual XF upgrade runner selects no new schema/member/purchase step from IosApi 1.0.32 or 1.0.33 to 1.0.34.\n";
    echo "Offline check only; normal XenForo data/cache import and live installation are not executed.\n";
}
