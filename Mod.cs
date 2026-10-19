using Colossal.IO.AssetDatabase;
using Colossal.Logging;
using ConfigurableElevatedRoad.Systems;
using Game;
using Game.Modding;
using Game.SceneFlow;
using HarmonyLib;
using System.Linq;
using Unity.Entities;


namespace ConfigurableElevatedRoad
{
    public class Mod : IMod
    {
        public static ILog log = LogManager.GetLogger($"{nameof(ConfigurableElevatedRoad)}").SetShowsErrorsInUI(false);
        public static Setting setting { get; private set; }
        public static readonly string harmonyID = "Jimmyok.ConfigurableElevatedRoad";

        public void OnLoad(UpdateSystem updateSystem)
        {
            log.Info(nameof(OnLoad));

            if (GameManager.instance.modManager.TryGetExecutableAsset(this, out var asset))
                log.Info($"Current mod asset at {asset.path}");

            setting = new Setting(this);
            setting.RegisterInOptionsUI();
            GameManager.instance.localizationManager.AddSource("en-US", new LocaleEN(setting));
            GameManager.instance.localizationManager.AddSource("zh-HANS", new LocaleCN(setting));

            // NOTE: as of game 1.6 this overload gained a 4th optional parameter
            // (LoadSettings(string name, object obj, object defaultObj, bool userSetting = false)).
            // The 3-argument call below still binds to it and keeps the previous behaviour/defaults.
            // Diagnostics: because the parameter list changed, an assembly that was compiled against
            // an older Game.dll binds to a method signature that no longer exists and the mod fails to
            // load with `MissingMethodException: void AssetDatabase.LoadSettings(string,object,object)`.
            // That is why this mod has to be *rebuilt* against the current assemblies, not just copied.
            AssetDatabase.global.LoadSettings(nameof(ConfigurableElevatedRoad), setting, new Setting(this));

            var harmony = new Harmony(harmonyID);
            harmony.PatchAll(typeof(Mod).Assembly);
            var patchedMethods = harmony.GetPatchedMethods().ToArray();
            log.Info($"Plugin {harmonyID} made patches! Patched methods: " + patchedMethods.Length);
            foreach (var patchedMethod in patchedMethods)
            {
                log.Info($"Patched method: {patchedMethod.Module.Name}:{patchedMethod.Name}");
            }
            World.DefaultGameObjectInjectionWorld.GetOrCreateSystem<NetCompositionDataFixSystem>();
            updateSystem.UpdateAfter<NetCompositionDataFixSystem>(SystemUpdatePhase.PrefabUpdate);
            updateSystem.UpdateBefore<NetCompositionDataFixSystem>(SystemUpdatePhase.PrefabReferences);
        }

        public void OnDispose()
        {
            var harmony = new Harmony(harmonyID);
            harmony.UnpatchAll(harmonyID);
            log.Info(nameof(OnDispose));
            if (setting != null)
            {
                setting.UnregisterInOptionsUI();
                setting = null;
            }
        }
    }
}
