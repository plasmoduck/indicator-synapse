
public class Main : Object
{
	// backend synapse initialization
	Type[] plugins = {
        typeof (Synapse.DesktopFilePlugin),
        typeof (Synapse.HybridSearchPlugin),
        typeof (Synapse.GnomeSessionPlugin),
        typeof (Synapse.GnomeScreenSaverPlugin),
        typeof (Synapse.SystemManagementPlugin),
        typeof (Synapse.CommandPlugin),
        typeof (Synapse.RhythmboxActions),
        typeof (Synapse.BansheeActions),
        typeof (Synapse.DirectoryPlugin),
        typeof (Synapse.LaunchpadPlugin),
        typeof (Synapse.CalculatorPlugin),
        typeof (Synapse.SelectionPlugin),
        typeof (Synapse.SshPlugin),
        typeof (Synapse.XnoiseActions),
#if HAVE_ZEITGEIST
        typeof (Synapse.ZeitgeistPlugin),
        typeof (Synapse.ZeitgeistRelated),
#endif
#if HAVE_LIBREST
        typeof (Synapse.ImgUrPlugin),
#endif
        // action-only plugins
        typeof (Synapse.DevhelpPlugin),
        typeof (Synapse.OpenSearchPlugin),
        // typeof (Synapse.LocatePlugin),
        typeof (Synapse.PastebinPlugin),
        typeof (Synapse.DictionaryPlugin),
		typeof (Synapse.FilezillaPlugin),
		typeof (Synapse.WolframAlphaPlugin)
	};

	public static Synapse.DataSink sink;
	public Menu menu { get; private set; }

	Cancellable? current_search = null;

	public Main ()
	{
		sink = new Synapse.DataSink ();
		foreach (var plugin in plugins) {
			sink.register_static_plugin (plugin);
		}

		menu = new Menu ();

		// our ui
		menu.search.connect ((text) => {
			if (current_search != null) {
				current_search.cancel ();
				current_search = null;
			}

			sink.search.begin (text, Synapse.QueryFlags.ALL, null, current_search, (obj, res) =>  {
				try {
					var matches = sink.search.end (res);
					menu.show_matches (matches);
				} catch (Error e) { warning (e.message); }
			});
		});
	}
}

public static Gdk.Pixbuf? find_icon (string name, int size)
{
	try {
		var icon = Icon.new_for_string (name);
		if (icon == null)
			return null;
		var info = Gtk.IconTheme.get_default ().lookup_by_gicon (icon, size, Gtk.IconLookupFlags.FORCE_SIZE);
		if (info == null)
			return null;
		return info.load_icon ();
	} catch (Error e) { warning (e.message); }

	return null;
}
