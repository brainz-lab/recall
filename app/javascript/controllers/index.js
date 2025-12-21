import { application } from "./application"

import HelloController from "./hello_controller"
import QueryController from "./query_controller"
import ExpandController from "./expand_controller"
import LiveTailController from "./live_tail_controller"
import ClipboardController from "./clipboard_controller"
import SavedSearchController from "./saved_search_controller"
import QueryHelpController from "./query_help_controller"
import ExportController from "./export_controller"

application.register("hello", HelloController)
application.register("query", QueryController)
application.register("expand", ExpandController)
application.register("live-tail", LiveTailController)
application.register("clipboard", ClipboardController)
application.register("saved-search", SavedSearchController)
application.register("query-help", QueryHelpController)
application.register("export", ExportController)
