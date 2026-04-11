import React from "react";
import { render } from "ink";
import App from "./app.js";
import { setInkInstance } from "./ink-instance.js";

const instance = render(React.createElement(App));
setInkInstance(instance);
