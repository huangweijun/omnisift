var SharePreprocessor = function() {};

SharePreprocessor.prototype = {
    run: function(arguments) {
        arguments.completionFunction({
            title: document.title || "",
            url: window.location.href || "",
            body: readableText(document)
        });
    }
};

function readableText(documentRef) {
    var article = documentRef.querySelector("article");
    var main = documentRef.querySelector("main");
    var source = article || main || documentRef.body;

    if (!source) {
        return "";
    }

    return source.innerText
        .replace(/\n{3,}/g, "\n\n")
        .replace(/[ \t]{2,}/g, " ")
        .trim();
}
