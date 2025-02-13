module plot

import json
import net
import net.http
import os
import time

type TracesWithTypeValue = Trace | string

struct PlotlyHandler {
	plot Plot
mut:
	server &http.Server [str: skip] = unsafe { nil }
}

fn (mut handler PlotlyHandler) handle(req http.Request) http.Response {
	mut r := http.Response{
		body: handler.plot.plotly()
		header: req.header
	}
	r.set_status(.ok)
	r.set_version(req.version)
	go fn [mut handler] () {
		time.sleep(300 * time.millisecond)
		handler.server.close()
	}()
	return r
}

// show starts a web server and opens a browser window to display the plot.
pub fn (plot Plot) show() ! {
	$if test ? {
		println('Ignoring plot.show() because we are running in test mode')
	} $else {
		mut handler := PlotlyHandler{
			plot: plot
		}
		listener := net.listen_tcp(net.AddrFamily.ip, ':0')!
		mut server := &http.Server{
			accept_timeout: 1 * time.second
			listener: listener
			port: 0
			handler: handler
		}
		handler.server = server
		t := spawn server.listen_and_serve()
		for server.status() != .running {
			time.sleep(10 * time.millisecond)
		}
		os.open_uri('http://${server.addr}')!
		t.wait()
	}
}

// TODO: This is a hack to allow the json encoder to work with sum types
fn encode[T](obj T) string {
	strings_to_replace := [
		',"[]f64"',
		'"[]f64"',
		',"[]string"',
		'"[]string"',
	]
	mut obj_json := json.encode(obj)
	for string_to_replace in strings_to_replace {
		obj_json = obj_json.replace(string_to_replace, '')
	}
	return obj_json
}

fn (plot Plot) plotly() string {
	traces_with_type := plot.traces.map({
		'type':  TracesWithTypeValue(it.trace_type())
		'trace': TracesWithTypeValue(it)
	})
	traces_with_type_json := encode(traces_with_type)
	layout_json := encode(plot.layout)

	return '<!DOCTYPE html>
<html>
  <head>
    <title>VSL Plot</title>
  </head>
  <body>
    <div id="gd"></div>

    <script type="module">
      import "https://cdn.plot.ly/plotly-2.26.2.min.js";
      
      function removeEmptyFieldsDeeply(obj) {
        if (Array.isArray(obj)) {
          return obj.map(removeEmptyFieldsDeeply);
        }
        if (typeof obj === "object") {
          const newObj = Object.fromEntries(
            Object.entries(obj)
              .map(([key, value]) => [key, removeEmptyFieldsDeeply(value)])
              .filter(([_, value]) => !!value)
          );
          return Object.keys(newObj).length > 0 ? newObj : undefined;
        }
        return obj;
      }

      const layout = ${layout_json};
      const traces_with_type_json = ${traces_with_type_json};
      const data = [...traces_with_type_json]
        .map(({ type, trace: { CommonTrace, _type, ...trace } }) => ({ type, ...CommonTrace, ...trace }));

      const payload = {
        data: removeEmptyFieldsDeeply(data),
        layout: removeEmptyFieldsDeeply(layout),
      };

      Plotly.newPlot("gd", payload);
    </script>
  </body>
</html>'
}
