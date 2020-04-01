# api-problem

## Building

build a installable XAR using

```bash
ant
```

## Remarks

The test directrory is not included in the build.
If you try the test module don't forget to make it executeable by everyone.
Of you don't you exist will ask you to log in (which is probably not what you want for a general purpose API).

As an example a controller.xql and an index.html are included that map the RestXQ API to the api-problem path.
controller.xql has no restrictions when forwarding to a RestXQ API.
