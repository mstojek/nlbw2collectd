'use strict';
'require baseclass';

return baseclass.extend({
	title: _('Nlbwmon'),

	rrdargs: function(graph, host, plugin, plugin_instance, dtype) {
		return [
			{
				title: "%H: Nlbwmon: Processed bytes in %pi",
				vlabel: "Bytes/s",
				number_format: "%5.1lf%sB/s",
				totals_format: "%5.1lf%sB",
				data: {
					types: [ "ipt_bytes" ],
					options: {
						ipt_bytes: {
							total: true,
							title: "%di"
						}
					}
				}
			},
			{
				title: "%H: Nlbwmon: Processed packets in %pi",
				vlabel: "Packets/s",
				number_format: "%5.1lf P/s",
				totals_format: "%5.1lf%s",
				data: {
					types: [ "ipt_packets" ],
					options: {
						ipt_packets: {
							total: true,
							title: "%di"
						}
					}
				}
			}
		];
	}
});
