$(document).ready(function (){
    $('input[type="submit"]').prop('disabled', true);

    function isZip(filename) {
        var parts = filename.split('.');
        return parts[parts.length - 1] == "zip";
    }

    $("#form").submit(function (e) {


        var url = "/uploadTest"
        var data = new FormData(this);
        $.ajax({
            type: "POST",
            url: url,
            contentType: false,
            processData: false,
            data: data, // serializes the form's elements.
            success: function(data)
            {
                 alert(data);
            }
        });

        e.preventDefault();
    });

    $("#file").change(function () {
        var file = $('#file');
        if (!isZip(file.val())) {
            $("#error").removeClass("hidden");
            $('input[type="submit"]').prop('disabled', true);
        }
        else {
            $('input[type="submit"]').prop('disabled', false);
            $("#error").addClass("hidden");
        }


    })
});
