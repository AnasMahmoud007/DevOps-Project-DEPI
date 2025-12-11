using Hotel.Model;
using Microsoft.AspNetCore.Authentication.Cookies; // Added for CookieAuthenticationDefaults

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorPages();
builder.Services.AddTransient<dbclass>();

// Add Authentication Services
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Login SingUp"; // Specify your login page path
        options.LogoutPath = "/Logout"; // Optional: Specify a logout path
    });


var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

// app.UseHttpsRedirection(); // Commented out for Docker development environment
app.UseStaticFiles();

app.UseRouting();

// Use Authentication middleware BEFORE Authorization
app.UseAuthentication(); // Added Authentication middleware
app.UseAuthorization();

app.MapRazorPages();

app.Run();
